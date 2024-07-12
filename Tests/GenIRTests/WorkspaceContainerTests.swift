import XCTest
@testable import gen_ir

final class WorkspaceContainerTests: XCTestCase {
	let testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("WorkspaceContainerTest")
			.appendingPathComponent("WorkspaceContainerTest.xcworkspace")
	}()
	let scheme = "App"

	func testWeirdGroupTagLocationParsing() throws {
		let context = TestContext()
		try context.build(test: testPath, scheme: scheme)
		let targets = context.targets

		XCTAssert(targets.count == 3)
		XCTAssertNotNil(targets.first(where: { $0.name == "App" }))
		XCTAssertNotNil(targets.first(where: { $0.name == "FrameworkA" }))
		XCTAssertNotNil(targets.first(where: { $0.name == "FrameworkB" }))
	}
}
