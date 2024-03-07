import XCTest
@testable import gen_ir			// .build/debug/gen_ir.build

class ManyTargetTests: XCTestCase {
	static private var testPath: URL = {
			TestContext.testAssetPath
				.appendingPathComponent("ManyTargetTest")
		}()
	static private var project = testPath.appendingPathComponent("ManyTargetTest.xcodeproj")
	static private var scheme = "ManyTargetTest"
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
			files = try FileManager.default.contentsOfDirectory(at: Self.context.irDirectory.appendingPathComponent("ManyTargetTest App.app"), includingPropertiesForKeys: nil)
		} catch {
			XCTFail("Directory ManyTargetTest App.app does not exist")
		}

		XCTAssertEqual(files.count, 3, "Wrong number files in App.app folder")

		var appBitcodeFound = false

		for file in files {
			if file.lastPathComponent == "ManyTargetTestApp.bc" {
				appBitcodeFound = true
			}
		}

		XCTAssertTrue(appBitcodeFound, "App bitcode file not found")
	}

	func testVerifyClipBitcodeFiles() throws {
		var files: [URL] = []

		do {
			files = try FileManager.default.contentsOfDirectory(at: Self.context.irDirectory.appendingPathComponent("ManyTargetTest App Clip.app"), includingPropertiesForKeys: nil)
		} catch {
			XCTFail("Directory ManyTargetTest App Clip.app does not exist")
		}

		XCTAssertEqual(files.count, 4, "Wrong number files in Clip.app folder")

		var clipBitcodeFound = false

		for file in files {
			if file.lastPathComponent == "ManyTargetTest App Clip-ManyTargetTest_App_ClipApp.bc" {
				clipBitcodeFound = true
			}
		}

		XCTAssertTrue(clipBitcodeFound, "Clip App bitcode file not found")
	}
}