import XCTest
@testable import gen_ir
import PBXProjParser

final class WorkspaceContainerTests: XCTestCase {
	static private var testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("WorkspaceContainerTest")
			.appendingPathComponent("WorkspaceContainerTest.xcworkspace")
	}()

	func testWeirdGroupTagLocationParsing() throws {
		let parser = try ProjectParser(path: Self.testPath, logLevel: .debug)
		let targets = parser.targets

		XCTAssert(targets.count == 3)
		XCTAssertNotNil(targets.first(where: { $0.name == "App" }))
		XCTAssertNotNil(targets.first(where: { $0.name == "FrameworkA" }))
		XCTAssertNotNil(targets.first(where: { $0.name == "FrameworkB" }))
	}
}
