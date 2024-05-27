import XCTest
@testable import gen_ir

final class CMakeDiscoveryTests: XCTestCase {
	let testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("CMakeDiscoveryTest")
			.appendingPathComponent(".build")
			.appendingPathComponent("CMakeDiscoveryTest.xcodeproj")
	}()

	private lazy var buildPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("CMakeDiscoveryTest")
			.appendingPathComponent(".build")
	}()

	let scheme = "CMakeDiscovery"

	private func generate() throws {
		if !FileManager.default.fileExists(atPath: buildPath.path) {
			try FileManager.default.createDirectory(at: buildPath, withIntermediateDirectories: true)
		}

		_ = try Process.runShell(
			"cmake",
			arguments: [
				"-GXcode",
				TestContext.testAssetPath.appendingPathComponent("CMakeDiscoveryTest").path
			],
			runInDirectory: buildPath
		)

		// If this isn't set - xcodebuild will refuse to clean the project (thanks Apple!)
		_ = try Process.runShell(
			"xattr",
			arguments: [
				"-w",
				"com.apple.xcode.CreatedByBuildSystem",
				"true",
				buildPath.appendingPathComponent("build").path
			]
		)
	}

	func testCMakeDiscovery() throws {
		try generate()
		let context = TestContext()
		try context.build(test: testPath, scheme: scheme)

		let cache = context.pifCache
		XCTAssertEqual(cache.targets.filter { $0.name == "CMakeDiscovery" }.count, 1)
	}
}
