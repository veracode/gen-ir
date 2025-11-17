import XCTest
@testable import gen_ir

final class DependencyChaseFilterTests: XCTestCase {
    let testPath: URL = {
        TestContext.testAssetPath
            .appendingPathComponent("DependencyChaseFilter")
            .appendingPathComponent("TestApp77.xcworkspace")
    }()
    let scheme = "TestApp77"

    func testDependencyChaseFilter() throws {
        let context = TestContext()
        try context.build(test: testPath, scheme: scheme)

        var runner = IREmitterCommand()
        try runner.run(
            log: context.buildLog.filePath,
            archive: context.archive,
            level: .debug,
            dryRun: false,
            dumpDependencyGraph: false
        )

        // Verify that the dependency chase filter worked as expected
        // Root of the IR should have 4 directories
        let irPath = context.archive.appendingPathComponent("IR")
        let files = try FileManager.default.contentsOfDirectory(at: irPath, includingPropertiesForKeys: [.isDirectoryKey], options: [])
        XCTAssertEqual(files.count, 4, "DependencyChaseFilterTests: Expected 4 IR directories to be generated")

				// Validate the contents of each root directory in the IR folder.
				try validateDirContents(context: context, dirName: "TestApp77.app", expectedCount: 4)
				try validateDirContents(context: context, dirName: "TestLibraryA.framework", expectedCount: 3)
				try validateDirContents(context: context, dirName: "TestLibraryB.framework", expectedCount: 368)
				try validateDirContents(context: context, dirName: "TestLibraryC.framework", expectedCount: 3)
    }

		private func validateDirContents(context: TestContext, dirName: String, expectedCount: Int) throws {
        // dirName should have expectedCount files
        let libPath = context.archive.appendingPathComponent("IR").appendingPathComponent(dirName)
        let files = try FileManager.default.contentsOfDirectory(at: libPath, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, expectedCount, "DependencyChaseFilterTests: Expected \(expectedCount) \(dirName) files to be generated")
		}
}
