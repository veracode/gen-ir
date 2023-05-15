import XCTest
@testable import gen_ir
import PBXProjParser

final class GenIRTests: XCTestCase {
	func testManyTargetTestTargets() throws {
		let projectPath = Utilities.assetsPath()
			.appendingPathComponent("ManyTargetTest")
			.appendingPathComponent("ManyTargetTest.xcodeproj")
		let project = try ProjectParser(path: projectPath, logLevel: logger.logLevel)
		let targets = Targets(for: project)

		print(targets)
		XCTAssert(targets.count == 3, "Targets count expected to be 3, was \(targets.count)")
		XCTAssertNotNil(targets.target(for: "ManyTargetTest"))
		XCTAssertNotNil(targets.filter({ $0.name == "ManyTargetTest"}).first, "ManyTargetTest target not found")
		XCTAssertNotNil(targets.filter({ $0.name == "ManyFramework"}).first, "ManyTargetTest target not found")
		XCTAssertNotNil(targets.filter({ $0.name == "ManyTargetTest"}).first, "ManyTargetTest target not found")
	}
}
