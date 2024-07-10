import XCTest
@testable import gen_ir

final class WorkspaceTests: XCTestCase {
	let testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("WorkspaceTest")
			.appendingPathComponent("Workspace.xcworkspace")
	}()

	let scheme = "App"

	static let appIRFiles: Set<String> = ["AppApp.bc", "ContentView.bc", "GeneratedAssetSymbols.bc"]
	static let commonIRFiles: Set<String> = ["Model.bc", "Common_vers.bc"]
	static let frameworkIRFiles: Set<String> = ["Framework.bc", "Framework_vers.bc"]
	static let sfSafeSymbolsIRFiles: Set<String> = [
		"NSImageExtension.bc",
		"SFSymbol+1.0.bc",
		"SFSymbol+1.1.bc",
		"SFSymbol+2.0.bc",
		"SFSymbol+2.1.bc",
		"SFSymbol+2.2.bc",
		"SFSymbol+3.0.bc",
		"SFSymbol+3.1.bc",
		"SFSymbol+3.2.bc",
		"SFSymbol+3.3.bc",
		"SFSymbol+4.0.bc",
		"SFSymbol+4.1.bc",
		"SFSymbol+AllSymbols+1.0.bc",
		"SFSymbol+AllSymbols+1.1.bc",
		"SFSymbol+AllSymbols+2.0.bc",
		"SFSymbol+AllSymbols+2.1.bc",
		"SFSymbol+AllSymbols+2.2.bc",
		"SFSymbol+AllSymbols+3.0.bc",
		"SFSymbol+AllSymbols+3.1.bc",
		"SFSymbol+AllSymbols+3.2.bc",
		"SFSymbol+AllSymbols+3.3.bc",
		"SFSymbol+AllSymbols+4.0.bc",
		"SFSymbol+AllSymbols+4.1.bc",
		"SFSymbol+AllSymbols.bc",
		"SFSymbol.bc",
		"SwiftUIImageExtension.bc",
		"SwiftUILabelExtension.bc",
		"SymbolLocalizations.bc",
		"SymbolWithLocalizations.bc",
		"UIApplicationShortcutIconExtension.bc",
		"UIButtonExtension.bc",
		"UIImageExtension.bc"
	]

	func testWorkspace() throws {
		let context = TestContext()
		try context.build(test: testPath, scheme: scheme)

		var genIR = gen_ir.IREmitterCommand()

		try genIR.run(
			log: context.buildLog.filePath,
			archive: context.archive,
			level: .debug,
			dryRun: false,
			dumpDependencyGraph: false
		)

		// Check dependencies made it to the right place. All dependencies should be statically
		// linked and appear under the .app directory.
		let appIRPath = context.archive.appending(path: "IR/App.app/")

		let expectedIRFiles = Self.appIRFiles
			.union(Self.commonIRFiles)
			.union(Self.frameworkIRFiles)
			.union(Self.sfSafeSymbolsIRFiles)

		let appIRPathContents = try FileManager.default.contentsOfDirectory(at: appIRPath, includingPropertiesForKeys: nil)
			.reduce(into: Set<String>(), { $0.insert($1.lastPathComponent) })

		XCTAssertEqual(expectedIRFiles, appIRPathContents, "App IR expected contents didn't equal actual: \(expectedIRFiles.symmetricDifference(appIRPathContents))")
	}
}
