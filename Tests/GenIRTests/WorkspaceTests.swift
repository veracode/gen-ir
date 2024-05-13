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
	static let commonIRFiles: Set<String> = ["Common_vers.bc", "Model.bc"]
	static let frameworkIRFiles: Set<String> = ["Framework_vers.bc", "Framework.bc"]
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
			project: testPath,
			log: context.buildLog.filePath,
			archive: context.archive,
			level: .debug,
			dryRun: false,
			dumpDependencyGraph: false
		)

		// Check dependencies made it to the right place
		let appIRPath = context.archive.appending(path: "IR/App.app/")
		let commonIRPath = context.archive.appending(path: "IR/Common.framework/")
		let frameworkIRPath = context.archive.appending(path: "IR/Framework.framework/")
		let sfSafeSymbolsIRPath = context.archive.appending(path: "IR/SFSafeSymbols.framework/")

		let appIRPathContents = try FileManager.default.contentsOfDirectory(at: appIRPath, includingPropertiesForKeys: nil)
			.reduce(into: Set<String>(), { $0.insert($1.lastPathComponent) })
		let commonIRPathContents = try FileManager.default.contentsOfDirectory(at: commonIRPath, includingPropertiesForKeys: nil)
			.reduce(into: Set<String>(), { $0.insert($1.lastPathComponent) })
		let frameworkIRPathContents = try FileManager.default.contentsOfDirectory(at: frameworkIRPath, includingPropertiesForKeys: nil)
			.reduce(into: Set<String>(), { $0.insert($1.lastPathComponent) })
		let sfSafeSymbolsIRPathContents = try FileManager.default.contentsOfDirectory(at: sfSafeSymbolsIRPath, includingPropertiesForKeys: nil)
			.reduce(into: Set<String>(), { $0.insert($1.lastPathComponent) })

		let expectedAppIRFiles = Self.appIRFiles
			.union(Self.commonIRFiles)
			.union(Self.frameworkIRFiles)
			.union(Self.sfSafeSymbolsIRFiles)
			.reduce(into: Set<String>(), { $0.insert($1) })

		let expectedFrameworkIRFiles = Self.frameworkIRFiles
			.union(Self.commonIRFiles)
			.union(Self.sfSafeSymbolsIRFiles)
			.reduce(into: Set<String>(), { $0.insert($1) })

		let expectedCommonIRFiles = Self.commonIRFiles
			.reduce(into: Set<String>(), { $0.insert($1) })

		let expectedSFSafeSymbolsIRFiles = Self.sfSafeSymbolsIRFiles
			.reduce(into: Set<String>(), { $0.insert($1) })

		XCTAssertEqual(expectedAppIRFiles, appIRPathContents, "App IR expected contents didn't equal actual")
		XCTAssertEqual(expectedFrameworkIRFiles, frameworkIRPathContents, "Framework IR expected contents didn't equal actual")
		XCTAssertEqual(expectedCommonIRFiles, commonIRPathContents, "Common IR expected contents didn't equal actual")
		XCTAssertEqual(expectedSFSafeSymbolsIRFiles, sfSafeSymbolsIRPathContents, "SFSafeSymbols IR expected contents didn't equal actual")
	}
}
