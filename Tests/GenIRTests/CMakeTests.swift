import XCTest
@testable import gen_ir

final class CMakeTests: XCTestCase {
	static private var testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("CMakeTest")
	}()
	//static private var project =  testPath.appendingPathComponent("build").appendingPathComponent("cmake-test.xcodeproj")
	static private var cmakeBinLocation = "/usr/local/bin/cmake"		// where homebrew installs cmake
	static private var scheme = "TEST_APP"
	static private var context: TestContext = try! TestContext()		// dangerous, but this is unit testing
	static private var cmakeSucceeded = true
	static private var cmakeBuildDir = "build"

	// this is called once before this suite of tests
	override class func setUp() {
		do {
			// check for CMake installed
			print("Checking that CMake is installed...")
			let process = try Process.runShell(
				Self.cmakeBinLocation,
				arguments: ["--version"])

			if process.code != 0 {
				print("'cmake --version' failed with \(process.stderr ?? "")")
				Self.cmakeSucceeded = false
				return
			}
		} catch {
			XCTFail("Failed to find cmake - is it installed?")
			Self.cmakeSucceeded = false
			return
		}

		do {
			// run CMake to create the Xcode project
			print("Running CMake to build the Xcode project...")
			let process = try Process.runShell(
				Self.cmakeBinLocation,
				 arguments: [
					"-S", ".",
					"-B", Self.context.temporaryDirectory.appendingPathComponent(Self.cmakeBuildDir).path,
					"-G", "Xcode"
				 ],
				 runInDirectory: Self.testPath
			)
			if process.code != 0 {
				print("Failed to create project with cmake: \(process.stderr ?? "")")
				Self.cmakeSucceeded = false
				return
			}
		} catch {
			XCTFail("Failed to setup test case")
			Self.cmakeSucceeded = false
		}
	}

	// this is called before each test
	override func setUp() {
		continueAfterFailure = false
	}

	static private let targetsToFiles = [
			"TEST_APP.app": ["ContentView.bc", "MyAppApp.bc"].sorted()
	]

	func cleanTempDir() {
		let files = try? FileManager.default.contentsOfDirectory(at: Self.context.temporaryDirectory, includingPropertiesForKeys: nil)

		for file in files ?? [] where file.lastPathComponent != Self.cmakeBuildDir {
			try? FileManager.default.removeItem(at: file)
		}

		// delete temp CMake files, since 'xcodebuild clean' won't (not created by the build system)
		try? FileManager.default.removeItem(at: Self.context.temporaryDirectory.appendingPathComponent(Self.cmakeBuildDir).appendingPathComponent("build"))
	}

	func testCMakeBasic() throws {
		defer { cleanTempDir() /*try? FileManager.default.removeItem(at: Self.context.temporaryDirectory) */}

		do {
			let process = try Self.context.cleanAndBuild(test: Self.context.temporaryDirectory.appendingPathComponent(Self.cmakeBuildDir), 
								project: Self.context.temporaryDirectory.appendingPathComponent(Self.cmakeBuildDir).appendingPathComponent("cmake-test.xcodeproj"), 
								scheme: Self.scheme)
			XCTAssertEqual(process.code, 0, "Failed to build test case")

			try Self.context.runGenIR(cmakeBuild: true)

		} catch {
			XCTFail("Failed to setup test case")
		}

		let appDirectory = Self.context.irDirectory.appendingPathComponent("TEST_APP.app")
		let contents = try FileManager.default.files(at: appDirectory, withSuffix: "bc")
				.map { $0.lastPathComponent }
				.sorted()

		XCTAssertEqual(contents, Self.targetsToFiles[appDirectory.lastPathComponent])
	}

	func testCMakeWithCustomDerivedData() throws {
		defer { cleanTempDir() /*try? FileManager.default.removeItem(at: Self.context.temporaryDirectory) */}

		do {
			let process = try Self.context.cleanAndBuild(test: Self.context.temporaryDirectory.appendingPathComponent(Self.cmakeBuildDir), 
								project: Self.context.temporaryDirectory.appendingPathComponent(Self.cmakeBuildDir).appendingPathComponent("cmake-test.xcodeproj"), 
								scheme: Self.scheme,
								additionalArguments: ["-derivedDataPath", "_build"])
			XCTAssertEqual(process.code, 0, "Failed to build test case")

			try Self.context.runGenIR(cmakeBuild: true)

		} catch {
			XCTFail("Failed to setup test case")
		}

		let appDirectory = Self.context.irDirectory.appendingPathComponent("TEST_APP.app")
		let contents = try FileManager.default.files(at: appDirectory, withSuffix: "bc")
				.map { $0.lastPathComponent }
				.sorted()

		XCTAssertEqual(contents, Self.targetsToFiles[appDirectory.lastPathComponent])
	}
}