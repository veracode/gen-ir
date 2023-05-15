import XCTest
@testable import gen_ir
import PBXProjParser

final class XCConfigTests: XCTestCase {
	func testCorrectTargetNameForXCConfig() throws {
		let configPath = Utilities.assetsPath()
			.appendingPathComponent("XCConfigurationTest")
			.appendingPathComponent("Debug.xcconfig")
		let parser = XCConfigParser(path: configPath)
		try parser.parse()

		XCTAssertEqual(parser.value(for: "TARGET_NAME"), "Config iOS Debug")
		// Should be able to access values defined in all imported files
		XCTAssertEqual(parser.value(for: "MIDDLE_TARGET_NAME"), "Config iOS")
		// Should be able to constrain values by their conditional assignments
		XCTAssertEqual(parser.value(for: "MIDDLE_TARGET_NAME", constrainedBy: [.sdk(.iOSSimulator)]), "Config iOS Sim")
		// Should be able to get values, with constraints, for items with no conditions
		XCTAssertEqual(parser.value(for: "BASE_TARGET_NAME", constrainedBy: [.arch(.arm), .sdk(.iOS)]), "Config")
	}
}
