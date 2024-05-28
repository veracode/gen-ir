import Foundation
@testable import gen_ir
import DependencyGraph
import XCTest

/// TestContext is a grouping of convenance functions and a context to ease the burden of testing Gen IR
class TestContext {
	enum Error: Swift.Error {
		case commandFailed(Process.ReturnValue)
		case invalidArgument(String)
	}

	/// The base folder path of the Gen IR project
	static let baseProjectPath: URL = {
		// HACK: use the #file magic to get a path to the test case... Maybe there's a better way to do this?
		URL(fileURLWithPath: #file.replacingOccurrences(of: "Tests/GenIRTests/TestContext.swift", with: ""))
	}()

	/// Path to the TestAssets folder
	static let testAssetPath: URL = {
		baseProjectPath.appendingPathComponent("TestAssets")
	}()

	/// Run xcodebuild's clean action
	/// - Parameters:
	///   - path: the path of the project to clean
	///   - scheme: the name of the scheme to clean (required for workspaces)
	/// - Returns:
	func clean(test path: URL, scheme: String) throws -> Process.ReturnValue {
		var arguments = ["clean"]

		switch path.pathExtension {
		case "xcodeproj":
			arguments.append(contentsOf: ["-project", path.filePath])
		case "xcworkspace":
			arguments.append(contentsOf: ["-workspace", path.filePath, "-scheme", scheme])
		default:
			throw Error.invalidArgument("path passed to clean(test:scheme:) was not xcodeproj or xcworkspace")
		}

		return try Process.runShell(
			"/usr/bin/xcodebuild",
			arguments: arguments,
			runInDirectory: path.deletingLastPathComponent(),
			joinPipes: true
		)
	}

	/// Run xcodebuild's archive action
	/// - Parameters:
	///   - path: the path of the project to build
	///   - scheme: the name of the scheme to build
	///   - additionalArguments: any additional arguments to passthrough to xcodebuild
	/// - Returns: the result of running the action.
	@discardableResult func build(
		test path: URL,
		scheme: String,
		additionalArguments: [String] = []
	) throws -> Process.ReturnValue {
		let clean = try clean(test: path, scheme: scheme)

		guard clean.code == 0 else {
			throw Error.commandFailed(clean)
		}

		let process = try Process.runShell(
			"/usr/bin/xcodebuild",
			arguments: [
				"archive",
				path.pathExtension == "xcworkspace" ? "-workspace" : "-project",
				path.filePath,
				"-scheme", scheme,
				"-destination", "generic/platform=iOS",
				"-configuration", "Debug",
				"-archivePath", archive.filePath,
				"DEBUG_INFORMATION_FORMAT=dwarf-with-dsym",
				"ENABLE_BITCODE=NO"
			]
			+ additionalArguments,
			runInDirectory: temporaryDirectory,
			joinPipes: true
		)

		if process.code != 0 {
			print("""
			code: \(process.code)
			stdout: \(process.stdout ?? "nil")
			stderr: \(process.stderr ?? "nil")
			""")
			throw Error.commandFailed(process)
		} else if let stdout = process.stdout {
			try stdout.write(to: buildLog, atomically: true, encoding: .utf8)
			buildLogContents = stdout.components(separatedBy: .newlines)
		}

		built = true

		return process
	}

	/// Path to the xcarchive (once built)
	let archive: URL
	/// Path to the build log (once built)
	let buildLog: URL
	/// Path to the temporary working directory for this context
	let temporaryDirectory: URL
	/// Has the project been built?
	private(set) var built = false
	/// Contents of the built build log
	private(set) var buildLogContents = [String]()

	/// Initializes the test context
	init() {
		// swiftlint:disable force_try
		temporaryDirectory = try! FileManager.default.temporaryDirectory(named: "gen-ir-tests-\(UUID().uuidString)")
		archive = temporaryDirectory.appendingPathComponent("x.xcarchive")
		buildLog = temporaryDirectory.appendingPathComponent("build.log")
	}

	deinit {
		try! FileManager.default.removeItem(at: temporaryDirectory)
		// swiftlint:enable force_try
	}

	/// Generate the log parser for this context
	lazy var logParser: XcodeLogParser = {
		XCTAssertTrue(built, "Requests a log parser without building the project")
		let parser = XcodeLogParser(log: buildLogContents)
		do {
			try parser.parse()
		} catch {
			fatalError("XcodeLogParser error: \(error)")
		}
		return parser
	}()

	/// Generate the PIF Cache for this context
	lazy var pifCache: PIFCache = {
		do {
			return try PIFCache(buildCache: logParser.buildCachePath)
		} catch {
			fatalError("PIFCache init failed with error: \(error)")
		}
	}()

	/// Generate the Targets for this context
	lazy var targets: [Target] = {
		Target.targets(from: pifCache.targets, with: logParser.targetCommands)
	}()

	/// Generate the dependency graph for this context
	lazy var graph: DependencyGraph<Target> = {
		DependencyGraphBuilder(provider: PIFDependencyProvider(targets: targets, cache: pifCache), values: targets).graph
	}()
}
