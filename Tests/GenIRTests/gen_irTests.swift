import XCTest
@testable import gen_ir
import PBXProjParser

final class GenIRTests: XCTestCase {
	func testManyTargetTestTargets() throws {
		// HACK: use the #file magic to get a path to the test case... Maybe there's a better way to do this?
		let packageRoot = URL(fileURLWithPath: #file.replacingOccurrences(of: "Tests/GenIRTests/gen_irTests.swift", with: ""))
		let projectPath = packageRoot
			.appendingPathComponent("TestAssets")
			.appendingPathComponent("ManyTargetTest")
			.appendingPathComponent("ManyTargetTest.xcodeproj")
		let project = try ProjectParser(path: projectPath, logLevel: logger.logLevel)
		var targets = Targets(for: project)

		print(targets)
		XCTAssert(targets.count == 3, "Targets count expected to be 3, was \(targets.count)")

		guard let app = targets.target(for: "ManyTargetTest") else {
			XCTAssert(false, "Failed to get target 'ManyTargetTest' from targets")
			return
		}

		XCTAssertNotNil(targets.filter({ $0.name == "ManyTargetTest"}).first, "ManyTargetTest target not found")
		XCTAssertNotNil(targets.filter({ $0.name == "ManyFramework"}).first, "ManyTargetTest target not found")
		XCTAssertNotNil(targets.filter({ $0.name == "ManyTargetTest"}).first, "ManyTargetTest target not found")
	}
}
