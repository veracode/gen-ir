import XCTest
@testable import gen_ir

final class OutputPostprocessorFileMoverTests: XCTestCase {
	let testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("OutputPostprocessorFileMoverTests")
			.appendingPathComponent("OutputPostprocessorFileMoverTests.xcodeproj")
	}()
	let scheme = "OutputPostprocessorFileMoverTests"

	func testFileMoving() throws {
		let context = TestContext()
		try context.build(test: testPath, scheme: scheme)

		var runner = IREmitterCommand()
		try runner.run(
			project: testPath,
			log: context.buildLog.filePath,
			archive: context.archive,
			level: .debug,
			dryRun: false,
			dumpDependencyGraph: false
		)

		// Check the output path for unique Image files
		let appIRPath = context.archive
			.appendingPathComponent("IR")
			.appendingPathComponent("OutputPostprocessorFileMoverTests.app")
		let files = try FileManager.default.contentsOfDirectory(at: appIRPath, includingPropertiesForKeys: nil)
		let imageFilesCount = files.filter { $0.lastPathComponent.starts(with: "Image") }.count

		// Only expecting two - one of the dependencies is dynamic and won't be moved.
		XCTAssertEqual(imageFilesCount, 2, "2 Image*.bc files expected, \(imageFilesCount) were found.")
	}
}
