import XCTest
@testable import gen_ir

final class UmbrellaTests: XCTestCase {
	let testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("Umbrella")
			.appendingPathComponent("Umbrella.xcworkspace")
	}()

	let scheme = "Umbrella"

	let targetsToFiles = [
			"Common.framework": ["Common_vers.bc", "Common-dummy.bc", "OrgModel.bc"].sorted(),
			"Networking.framework": ["Networking_vers.bc", "Networking-dummy.bc", "Networking.bc"].sorted(),
			"Pods_Umbrella.framework": ["Pods_Umbrella_vers.bc", "Pods-Umbrella-dummy.bc"].sorted(),
			"Umbrella.framework": ["GetOrg.bc", "Umbrella_vers.bc"].sorted()
	]

	func testUmbrellaTargets() throws {
		let context = TestContext()
		try context.build(test: testPath, scheme: scheme)

		let targets = context.targets
		XCTAssertEqual(targets.count, 4, "Expected 4 targets, got \(targets.count)")

		let expectedTargetNames = ["Umbrella", "Common", "Networking", "Pods-Umbrella"].sorted()
		let actualTargetNames = targets.map { $0.name }.sorted()
		XCTAssertEqual(
			actualTargetNames, expectedTargetNames,
			"Expected target names: \(expectedTargetNames), got: \(actualTargetNames)"
		)
	}

	func testSkipInstallNo() throws {
		let context = TestContext()
		try context.build(test: testPath, scheme: scheme, additionalArguments: ["SKIP_INSTALL=NO"])

		let output = context.archive.appendingPathComponent("IR")

		var genIR = gen_ir.IREmitterCommand()
		try genIR.run(
			log: context.buildLog.filePath,
			archive: context.archive,
			level: .debug,
			dryRun: false,
			dumpDependencyGraph: false
		)

		let directories = try FileManager.default.directories(at: output, recursive: false)
		let targets = directories.map { $0.lastPathComponent }

		XCTAssertEqual(targets.sorted(), targetsToFiles.keys.sorted(), "Targets list doesn't match the known targets")

		for directory in directories {
			let contents = try FileManager.default.files(at: directory, withSuffix: "bc")
				.map { $0.lastPathComponent }
				.sorted()

			XCTAssertEqual(contents, targetsToFiles[directory.lastPathComponent])
		}
	}

	func testCustomDerivedDataAndSkipInstallNo() throws {
		let context = TestContext()
		try context.build(test: testPath, scheme: scheme, additionalArguments: ["SKIP_INSTALL=NO", "-derivedDataPath", "_build"])

		let output = context.archive.appendingPathComponent("IR")

		var genIR = gen_ir.IREmitterCommand()
		try genIR.run(
			log: context.buildLog.filePath,
			archive: context.archive,
			level: .debug,
			dryRun: false,
			dumpDependencyGraph: false
		)

		let directories = try FileManager.default.directories(at: output, recursive: false)
		let targets = directories.map { $0.lastPathComponent }

		XCTAssertEqual(targets.sorted(), targetsToFiles.keys.sorted(), "Targets list doesn't match the known targets")

		for directory in directories {
			let contents = try FileManager.default.files(at: directory, withSuffix: "bc")
				.map { $0.lastPathComponent }
				.sorted()

			XCTAssertEqual(contents, targetsToFiles[directory.lastPathComponent])
		}
	}
}
