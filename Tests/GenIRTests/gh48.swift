import XCTest
@testable import gen_ir			// .build/debug/gen_ir.build

class GH48Tests: XCTestCase {
	static private var testPath: URL = {
			TestContext.testAssetPath
				.appendingPathComponent("GH48")
		}()
	static private var project = testPath.appendingPathComponent("MyApp.xcodeproj")
	static private var scheme = "MyApp"
	static private var context: TestContext = try! TestContext()		// dangerous, but this is unit testing

	override class func setUp() {
		do {
			let process = try context.cleanAndBuild(test: Self.testPath, project: Self.project, scheme: Self.scheme)
			XCTAssertEqual(process.code, 0, "Failed to build test case")

			try Self.context.runGenIR()
		} catch {
			XCTFail("Failed to setup test case")
		}
	}

	func testVerifyIRDirectory() throws {
		let files = try FileManager.default.contentsOfDirectory(at: Self.context.irDirectory, includingPropertiesForKeys: nil)

		XCTAssertEqual(files.count, 1, "Wrong number directories in IR folder")
		XCTAssert(files[0].lastPathComponent == "MyApp.app", "Folder 'MyApp.app' not in IR folder")
	}

	func testVerifyBitcodeFiles() throws {
		continueAfterFailure = false
		var files: [URL] = []

		do {
			files = try FileManager.default.contentsOfDirectory(at: Self.context.irDirectory.appendingPathComponent("MyApp.app"), includingPropertiesForKeys: nil)
		} catch {
			XCTFail("Directory MyApp.app does not exist")
		}

		XCTAssertEqual(files.count, 4, "Wrong number files in App folder")

		var appBitcodeFound = false
		var testPackageBitcodeFound = false

		for file in files {
			if file.lastPathComponent == "MyAppApp.bc" {
				appBitcodeFound = true
			}

			if file.lastPathComponent == "TestPackage-TestPackage.bc" {
				testPackageBitcodeFound = true
			}
		}

		XCTAssertTrue(appBitcodeFound, "App bitcode file not found")
		XCTAssertTrue(testPackageBitcodeFound, "TestPackage bitcode file not found")
	}
}