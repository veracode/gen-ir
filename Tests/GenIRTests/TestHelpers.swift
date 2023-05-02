import Foundation
@testable import gen_ir

class TestContext {
	static let baseTestingPath: URL = {
		// HACK: use the #file magic to get a path to the test case... Maybe there's a better way to do this?
		URL(fileURLWithPath: #file.replacingOccurrences(of: "Tests/GenIRTests/TestHelpers.swift", with: ""))
	}()

	static func buildTest(
		at path: URL,
		additionalArguments: [String] = []
	) throws -> (success: Bool, context: TestContext) {
		let context = try TestContext()

		let process = try Process.runShell(
			"/usr/bin/xcodebuild",
			arguments: [
				context.archive.filePath,
				context.buildLog.filePath
			] + additionalArguments,
			runInDirectory: context.temporaryDirectory
		)

		if process.code != 0 {
			if let stdout = process.stdout {
				print("stdout -- \(stdout)")
			}

			if let stderr = process.stderr {
				print("stderr -- \(stderr)")
			}
		}

		return (process.code == 0, context)
	}

	let archive: URL
	let buildLog: URL
	let temporaryDirectory: URL

	private init() throws {
		temporaryDirectory = try FileManager.default.temporaryDirectory(named: "gen-ir-tests-")
		archive = temporaryDirectory.appendingPathComponent("x.xcarchive")
		buildLog = temporaryDirectory.appendingPathComponent("build.log")
	}

	deinit {
		try? FileManager.default.removeItem(at: temporaryDirectory)
	}
}
