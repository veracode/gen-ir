import Foundation
@testable import gen_ir

class TestContext {
	enum Error: Swift.Error {
		case commandFailed(Process.ReturnValue)
	}

	static let baseTestingPath: URL = {
		// HACK: use the #file magic to get a path to the test case... Maybe there's a better way to do this?
		URL(fileURLWithPath: #file.replacingOccurrences(of: "Tests/GenIRTests/TestContext.swift", with: ""))
	}()

	static let testAssetPath: URL = {
		baseTestingPath.appendingPathComponent("TestAssets")
	}()

	func clean(test path: URL) throws -> Process.ReturnValue {
		return try Process.runShell(
			"/usr/bin/xcodebuild",
			arguments: ["clean"],
			runInDirectory: path.deletingLastPathComponent(),
			joinPipes: true
		)
	}

	func build(
		test path: URL,
		scheme: String,
		additionalArguments: [String] = []
	) throws -> Process.ReturnValue {
		let clean = try clean(test: path)

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
		}

		return process
	}

	let archive: URL
	let buildLog: URL
	let temporaryDirectory: URL

	init() throws {
		temporaryDirectory = try FileManager.default.temporaryDirectory(named: "gen-ir-tests-\(UUID().uuidString)")
		archive = temporaryDirectory.appendingPathComponent("x.xcarchive")
		buildLog = temporaryDirectory.appendingPathComponent("build.log")
	}
}
