import XCTest
@testable import gen_ir

final class MultipleAppTests: XCTestCase {
	static private var testPath: URL = {
			TestContext.testAssetPath
				.appendingPathComponent("MultipleApp")
		}()
	static private var project = testPath.appendingPathComponent("MultipleApp.xcodeproj")
	static private var scheme = "MultipleApp"
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
			files = try FileManager.default.contentsOfDirectory(at: Self.context.irDirectory.appendingPathComponent("MultipleApp.app"), includingPropertiesForKeys: nil)
		} catch {
			XCTFail("Directory MultipleApp.app does not exist")
		}

		XCTAssertEqual(files.count, 3, "Wrong number files in App.app folder")

		var appBitcodeFound = false

		for file in files {
			if file.lastPathComponent == "MultipleAppApp.bc" {
				appBitcodeFound = true
			}
		}

		XCTAssertTrue(appBitcodeFound, "App bitcode file not found")
	}

	func testVerifyAppCopyBitcodeFiles() throws {
		var files: [URL] = []

		do {
			files = try FileManager.default.contentsOfDirectory(at: Self.context.irDirectory.appendingPathComponent("MultipleApp Copy.app"), includingPropertiesForKeys: nil)
		} catch {
			XCTFail("Directory MultipleApp Copy.app does not exist")
		}

		XCTAssertEqual(files.count, 4, "Wrong number files in Copy.app folder")

		var copyBitcodeFound = false
		var onlyBitcodeFound = false

		for file in files {
			if file.lastPathComponent == "MultipleAppApp.bc" {
				copyBitcodeFound = true
			}
		}

		for file in files {
			if file.lastPathComponent == "CopyOnly.bc" {
				onlyBitcodeFound = true
			}
		}

		XCTAssertTrue(copyBitcodeFound, "App bitcode file not found")
		XCTAssertTrue(onlyBitcodeFound, "CopyOnly bitcode file not found")
	}
}
