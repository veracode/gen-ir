import Foundation
@testable import gen_ir
import XCTest

class TestContext {
	enum Error: Swift.Error {
		case commandFailed(Process.ReturnValue)
		case invalidArgument(String)
		case notBuilt
	}

	static let baseTestingPath: URL = {
		// HACK: use the #file magic to get a path to the test case... Maybe there's a better way to do this?
		URL(fileURLWithPath: #file.replacingOccurrences(of: "Tests/GenIRTests/TestContext.swift", with: ""))
	}()

	static let testAssetPath: URL = {
		baseTestingPath.appendingPathComponent("TestAssets")
	}()

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

	@discardableResult
	func build(
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

	let archive: URL
	let buildLog: URL
	let temporaryDirectory: URL
	private(set) var built = false
	private(set) var buildLogContents = [String]()

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

	lazy var pifCache: PIFCache = {
		do {
			return try PIFCache(buildCache: logParser.buildCachePath)
		} catch {
			fatalError("PIFCache init failed with error: \(error)")
		}
	}()

	lazy var targets: [Target] = {
		Target.targets(from: pifCache.targets, with: logParser.targetCommands)
	}()

	lazy var graph: DependencyGraph<Target> = {
		DependencyGraphBuilder(provider: PIFDependencyProvider(targets: targets, cache: pifCache), values: targets).graph
	}()
}
