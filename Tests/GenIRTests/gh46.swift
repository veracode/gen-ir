import XCTest
@testable import gen_ir			// .build/debug/gen_ir.build

class GH46Tests: XCTestCase {
	static private var testPath: URL = {
			TestContext.testAssetPath
				.appendingPathComponent("GH46")
	}()
	static private var project = testPath.appendingPathComponent("GH46.xcworkspace")
	static private var scheme = "KeithTestApp"
	static private var context: TestContext = try! TestContext()		// dangerous, but this is unit testing
	static private var buildSucceeded = true

	// this is called once before this suite of tests
	override class func setUp() {
		do {
			let process = try context.cleanAndBuild(test: Self.testPath, project: Self.project, scheme: Self.scheme)
			XCTAssertEqual(process.code, 0, "Failed to build test case")

			try Self.context.runGenIR()
		} catch {
			XCTFail("Failed to setup test case")
			Self.buildSucceeded = false
		}
	}

	// this is called before each test
	override func setUp() {
		continueAfterFailure = false
		XCTAssertTrue(Self.buildSucceeded, "Failed to build test case, aborting")
	}

	func testVerifyIRDirectory() throws {
		let files = try FileManager.default.contentsOfDirectory(at: Self.context.irDirectory, includingPropertiesForKeys: nil)

		XCTAssertEqual(files.count, 2, "Wrong number directories in IR folder")
	}

	func testVerifyAppBitcodeFiles() throws {
		var files: [URL] = []

		do {
			files = try FileManager.default.contentsOfDirectory(at: Self.context.irDirectory.appendingPathComponent("KeithTestApp.app"), includingPropertiesForKeys: nil)
		} catch {
			XCTFail("Directory KeithTestApp.app does not exist")
		}

		XCTAssertEqual(files.count, 3, "Wrong number files in App folder")

		var appBitcodeFound = false

		for file in files {
			if file.lastPathComponent == "KeithTestAppApp.bc" {
				appBitcodeFound = true
			}
		}

		XCTAssertTrue(appBitcodeFound, "App bitcode file not found")
	}

	func testVerifyFrameworkBitcodeFiles() throws {
		var files: [URL] = []

		do {
			files = try FileManager.default.contentsOfDirectory(at: Self.context.irDirectory.appendingPathComponent("KeithTestApp.framework"), includingPropertiesForKeys: nil)
		} catch {
			XCTFail("Directory KeithTestApp.framework does not exist")
		}

		XCTAssertEqual(files.count, 2, "Wrong number files in Framework folder")

		var frameworkBitcodeFound = false

		for file in files {
			if file.lastPathComponent == "KeithTestApp-TestFile.bc" {
				frameworkBitcodeFound = true
			}
		}

		XCTAssertTrue(frameworkBitcodeFound, "Framework bitcode file not found")
	}
}