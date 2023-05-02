import XCTest
@testable import gen_ir
import PBXProjParser

final class UmbrellaTests: XCTestCase {
	static private var testPath: URL = {
		TestContext.baseTestingPath
			.appendingPathComponent("TestAssets")
			.appendingPathComponent("Umbrella")
			.appendingPathComponent("Umbrella.xcworkspace")
	}()

	func testUmbrellaTargets() throws {
		let (success, context) = try TestContext.buildTest(at: UmbrellaTests.testPath)
		XCTAssertTrue(success, "Failed to build test case")

		let projectParser = try ProjectParser(path: Self.testPath, logLevel: .info)
		let targets = Targets(for: projectParser)

		XCTAssert(targets.count == 4, "Expected 4 targets, got \(targets.count)")

		let expectedTargetNames = ["Umbrella", "Common", "Networking", "Pods-Umbrella"].sorted()
		let actualTargetNames = targets.map { $0.name }.sorted()

		XCTAssert(
			actualTargetNames == expectedTargetNames,
			"Expected target names: \(expectedTargetNames), got: \(actualTargetNames)"
		)



	}
}
