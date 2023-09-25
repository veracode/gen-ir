import XCTest
@testable import gen_ir
import PBXProjParser

final class OutputPostprocessorFileMoverTests: XCTestCase {
	static private var testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("OutputPostprocessorFileMoverTests")
			.appendingPathComponent("OutputPostprocessorFileMoverTests.xcodeproj")
	}()

	func testFileMoving() throws {
		let context = try TestContext()
		let result = try context.build(test: Self.testPath, scheme: "OutputPostprocessorFileMoverTests")
		XCTAssertEqual(result.code, 0, "Build returned non-zero exit code")

		var runner = IREmitterCommand()
		try runner.run(
			project: Self.testPath,
			log: context.buildLog.filePath,
			archive: context.archive,
			level: .debug,
			dryRun: false
		)

		// Check the output path for unique Image files
		print("archivePAth: \(context.archive)")
		let appIRPath = context.archive
			.appendingPathComponent("IR")
			.appendingPathComponent("OutputPostprocessorFileMoverTests.app")
		let files = try FileManager.default.contentsOfDirectory(at: appIRPath, includingPropertiesForKeys: nil)
		let imageFilesCount = files.filter { $0.lastPathComponent.starts(with: "Image") }.count
		print("imageFilesCount: \(imageFilesCount)")

		// Only expecting two - one of the dependencies is dynamic and won't be moved.
		XCTAssertEqual(imageFilesCount, 2, "2 Image*.bc files expected, \(imageFilesCount) were found.")
	}
}
