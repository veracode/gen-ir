import XCTest
@testable import gen_ir
import PBXProjParser

final class WorkspaceTests: XCTestCase {
	static private var testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("WorkspaceTest")
			.appendingPathComponent("Workspace.xcworkspace")
	}()

	static private var scheme = "App"

	func testWorkspace() throws {
		let context = try TestContext()
		let process = try context.build(test: Self.testPath, scheme: Self.scheme)
		XCTAssertEqual(process.code, 0, "Failed to build test case")

		let output = context.archive.appendingPathComponent("IR")
		var genIR = gen_ir.IREmitterCommand()

		try genIR.run(
			project: Self.testPath,
			log: context.buildLog.filePath,
			archive: context.archive,
			output: output,
			level: .debug,
			dryRun: false
		)

		print("ran Gen IR")
	}
}
