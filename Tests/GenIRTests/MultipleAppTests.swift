import XCTest
@testable import gen_ir

final class MultipleAppTests: XCTestCase {
	let testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("MultipleApp")
			.appendingPathComponent("MultipleApp.xcodeproj")
	}()
	let scheme = "MultipleApp"

	func testExpectedTargetLookup() throws {
		let context = TestContext()
		try context.build(test: testPath, scheme: "MultipleApp")

		let targets = context.targets

		let app = try XCTUnwrap(targets.first(where: { $0.name == "MultipleApp" }))
		let copy = try XCTUnwrap(targets.first(where: { $0.name == "MultipleApp Copy" }))

        XCTAssertEqual(context.logParser.targetCommands[app.name]?.count, 1)
        XCTAssertEqual(context.logParser.targetCommands[copy.name]?.count, 1)
	}
}
