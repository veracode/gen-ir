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

	var temporaryDirectory: URL
	var archive: URL
	var buildLog: URL
	var irDirectory: URL
	
	init() throws {
		temporaryDirectory = try FileManager.default.temporaryDirectory(named: "gen-ir-tests-\(UUID().uuidString)")
		archive = temporaryDirectory.appendingPathComponent("x.xcarchive")
		buildLog = temporaryDirectory.appendingPathComponent("build.log")
		irDirectory = archive.appendingPathComponent("IR")

		print("tempDir = \(temporaryDirectory)")
	}

	func clean(test path: URL) throws -> Process.ReturnValue {
		return try Process.runShell(
			"/usr/bin/xcodebuild",
			arguments: ["clean"],
			runInDirectory: path/*.deletingLastPathComponent()*/,
			joinPipes: true
		)
	}

	func cleanAndBuild(
		test path: URL,
		project: URL,
		scheme: String,
		additionalArguments: [String] = []
	) throws -> Process.ReturnValue {
		print("cleaning \(project)")
		let clean = try clean(test: path)

		guard clean.code == 0 else {
			throw Error.commandFailed(clean)
		}

		print("building \(project)")
		let process = try Process.runShell(
			"/usr/bin/xcodebuild",
			arguments: [
				"archive",
				project.pathExtension == "xcworkspace" ? "-workspace" : "-project",
				project.filePath,
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

	func runGenIR() throws {
		/* testing swift cmd-line apps is not very well supported by Apple, 
		  What we really need is access to the TestHelpers in the ArgumentParser package (https://github.com/apple/swift-argument-parser/blob/main/Package.swift)
		  But that's not available as a product, so we work around that
		*/

		var genIR = gen_ir.IREmitterCommand()

		try FileManager.default.createDirectory(at: self.archive.appendingPathComponent("IR"), withIntermediateDirectories: true)
		
		try genIR.run(
			project: URL(string: "ignored")!,
			log: self.buildLog.filePath,
			archive: self.archive,
			output: self.irDirectory,
			dryRun: false
		)
	}
}
