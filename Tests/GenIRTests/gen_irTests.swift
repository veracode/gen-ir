import XCTest
@testable import gen_ir

final class GenIRTests: XCTestCase {
	func testManyTargetTestTargets() throws {
		let context = TestContext()
		let projectPath = TestContext.baseProjectPath
			.appendingPathComponent("TestAssets")
			.appendingPathComponent("ManyTargetTest")
			.appendingPathComponent("ManyTargetTest.xcodeproj")

		try context.build(test: projectPath, scheme: "ManyTargetTest")
		let targets = context.targets

		XCTAssert(targets.count == 3, "Targets count expected to be 3, was \(targets.count)")

		XCTAssertNotNil(targets.filter({ $0.name == "ManyTargetTest"}).first, "ManyTargetTest target not found")
		XCTAssertNotNil(targets.filter({ $0.name == "ManyFramework"}).first, "ManyTargetTest target not found")
		XCTAssertNotNil(targets.filter({ $0.name == "ManyTargetTest"}).first, "ManyTargetTest target not found")
	}
}
