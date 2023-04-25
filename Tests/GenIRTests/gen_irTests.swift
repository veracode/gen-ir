import XCTest
@testable import gen_ir
import PBXProjParser

final class GenIRTests: XCTestCase {
	func testManyTargetTestTargets() throws {
		let projectPath = baseTestingPath()
			.appendingPathComponent("TestAssets")
			.appendingPathComponent("ManyTargetTest")
			.appendingPathComponent("ManyTargetTest.xcodeproj")
		let project = try ProjectParser(path: projectPath, logLevel: logger.logLevel)
		let targets = Targets(for: project)

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
