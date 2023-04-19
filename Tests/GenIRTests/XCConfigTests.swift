import XCTest
@testable import gen_ir
import PBXProjParser

final class XCConfigTests: XCTestCase {
	func testCorrectTargetNameForXCConfig() throws {
		let projectPath = URL(fileURLWithPath: "TestAssets/XCConfigurationTest/XCConfigurationTest.xcodeproj")
		let project = try ProjectParser(path: projectPath, logLevel: logger.logLevel)
		let targets = Targets(for: project)

		print(targets.map { $0.productName })
	}
}