import XCTest
@testable import gen_ir

final class UmbrellaTests: XCTestCase {
	static private var testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("Umbrella")
	}()
	static private var project = testPath.appendingPathComponent("Umbrella.xcworkspace")
	static private var scheme = "Umbrella"

	// this is called before each test
	override func setUp() {
		continueAfterFailure = false
	}

	static private let targetsToFiles = [
			"Common.framework": ["Common_vers.bc", "Common-dummy.bc", "OrgModel.bc"].sorted(),
			"Networking.framework": ["Networking_vers.bc", "Networking-dummy.bc", "Networking.bc"].sorted(),
			"Pods_Umbrella.framework": ["Pods_Umbrella_vers.bc", "Pods-Umbrella-dummy.bc"].sorted(),
			"Umbrella.framework": ["GetOrg.bc", "Umbrella_vers.bc"].sorted()
	]

	func testSkipInstallNo() throws {
		let context = try TestContext()

		defer { try? FileManager.default.removeItem(at: context.temporaryDirectory) }

		do {
			let process = try context.cleanAndBuild(test: Self.testPath, project: Self.project, 
					scheme: Self.scheme, additionalArguments: ["SKIP_INSTALL=NO"])
			XCTAssertEqual(process.code, 0, "Failed to build test case")

			try context.runGenIR()
		} catch {
			XCTFail("Failed to setup test case")
		}

		let directories = try FileManager.default.directories(at: context.irDirectory, recursive: false)
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
		let context = try TestContext()

		defer { try? FileManager.default.removeItem(at: context.temporaryDirectory) }

		do {
			let process = try context.cleanAndBuild(test: Self.testPath, project: Self.project, 
					scheme: Self.scheme, additionalArguments: ["SKIP_INSTALL=NO", "-derivedDataPath", "_build"])
			XCTAssertEqual(process.code, 0, "Failed to build test case")

			try context.runGenIR()
		} catch {
			XCTFail("Failed to setup test case")
		}

		let directories = try FileManager.default.directories(at: context.irDirectory, recursive: false)
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