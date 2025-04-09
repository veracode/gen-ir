import XCTest
@testable import gen_ir

final class MultipleAppTests: XCTestCase {
	let testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("MultipleApp")
			.appendingPathComponent("MultipleApp.xcodeproj")
	}()
	let scheme = "MultipleApp"

	func skip_testExpectedTargetLookup() throws {
		let context = TestContext()
		try context.build(test: testPath, scheme: "MultipleApp")

		let targets = context.targets

		let app = try XCTUnwrap(targets.first(where: { $0.name == "MultipleApp" }))
		let copy = try XCTUnwrap(targets.first(where: { $0.name == "MultipleApp Copy" }))

		let appKey = TargetKey(projectName: "MultipleApp", targetName: app.name)
		let copyKey = TargetKey(projectName: "MultipleApp", targetName: copy.name)

        XCTAssertEqual(context.logParser.commandLog[1].target, appKey)
		XCTAssertEqual(context.logParser.commandLog[2].target, copyKey)
	}
}
