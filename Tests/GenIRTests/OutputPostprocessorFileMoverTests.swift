import XCTest
@testable import gen_ir
import PBXProjParser

final class OutputPostprocessorFileMoverTests: XCTestCase {
	static private var testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("OutputPostprocessorFileMoverTests")
			.appendingPathComponent("OutputPostprocessorFileMoverTests.xcodeproj")
	}()
}
