import XCTest
@testable import gen_ir
import PBXProjParser

final class UmbrellaTests: XCTestCase {
	static private var testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("Umbrella")
			.appendingPathComponent("Umbrella.xcworkspace")
	}()

	static private var scheme = "Umbrella"

	static private let targetsToFiles = [
			"Common.framework": ["Common_vers.bc", "Common-dummy.bc", "OrgModel.bc"].sorted(),
			"Networking.framework": ["Networking_vers.bc", "Networking-dummy.bc", "Networking.bc"].sorted(),
			"Pods_Umbrella.framework": ["Pods_Umbrella_vers.bc", "Pods-Umbrella-dummy.bc"].sorted(),
			"Umbrella.framework": ["GetOrg.bc", "Umbrella_vers.bc"].sorted()
	]

	func testUmbrellaTargets() async throws {
		let context = try TestContext()
		let process = try context.build(test: Self.testPath, scheme: Self.scheme)
		XCTAssertEqual(process.code, 0, "Failed to build test case")

		let projectParser = try await ProjectParser(path: Self.testPath, logLevel: .info)
		let targets = Targets(for: projectParser)

		XCTAssertEqual(targets.count, 4, "Expected 4 targets, got \(targets.count)")

		let expectedTargetNames = ["Umbrella", "Common", "Networking", "Pods-Umbrella"].sorted()
		let actualTargetNames = targets.map { $0.name }.sorted()

		XCTAssertEqual(
			actualTargetNames, expectedTargetNames,
			"Expected target names: \(expectedTargetNames), got: \(actualTargetNames)"
		)
	}

	func testSkipInstallNo() throws {
		let context = try TestContext()
		defer { try? FileManager.default.removeItem(at: context.temporaryDirectory) }
		_ = try context.build(test: Self.testPath, scheme: Self.scheme, additionalArguments: ["SKIP_INSTALL=NO"])

		let output = context.archive.appendingPathComponent("IR")

		var genIR = gen_ir.IREmitterCommand()
		try genIR.run(
			project: Self.testPath,
			log: context.buildLog.filePath,
			archive: context.archive,
			output: output,
			level: .debug,
			dryRun: false
		)

		let directories = try FileManager.default.directories(at: output, recursive: false)
		let targets = directories.map { $0.lastPathComponent }

		XCTAssertEqual(targets.sorted(), Self.targetsToFiles.keys.sorted(), "Targets list doesn't match the known targets")

		for directory in directories {
			let contents = try FileManager.default.files(at: directory, withSuffix: "bc")
				.map { $0.lastPathComponent }
				.sorted()

			XCTAssertEqual(contents, Self.targetsToFiles[directory.lastPathComponent])
		}
	}

	func testCustomDerivedDataAndSkipInstallNo() throws {
		let context = try TestContext(podsBuildSystemHack: true)
		defer { try? FileManager.default.removeItem(at: context.temporaryDirectory) }
		_ = try context.build(test: Self.testPath, scheme: Self.scheme, additionalArguments: ["SKIP_INSTALL=NO", "-derivedDataPath", "_build"])

		let output = context.archive.appendingPathComponent("IR")

		var genIR = gen_ir.IREmitterCommand()
		try genIR.run(
			project: Self.testPath,
			log: context.buildLog.filePath,
			archive: context.archive,
			output: output,
			level: .debug,
			dryRun: false
		)

		let directories = try FileManager.default.directories(at: output, recursive: false)
		let targets = directories.map { $0.lastPathComponent }

		XCTAssertEqual(targets.sorted(), Self.targetsToFiles.keys.sorted(), "Targets list doesn't match the known targets")

		for directory in directories {
			let contents = try FileManager.default.files(at: directory, withSuffix: "bc")
				.map { $0.lastPathComponent }
				.sorted()

			XCTAssertEqual(contents, Self.targetsToFiles[directory.lastPathComponent])
		}
	}
}
