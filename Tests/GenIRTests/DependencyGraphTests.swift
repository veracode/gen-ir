import XCTest
@testable import gen_ir
import PBXProjParser

final class DependencyGraphTests: XCTestCase {
	static private var testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("WorkspaceTest")
			.appendingPathComponent("Workspace.xcworkspace")
	}()

	static private var scheme = "App"

	func testChains() throws {
		// Test Setup
		let context = try TestContext()
		let process = try context.build(test: Self.testPath, scheme: Self.scheme)
		XCTAssertEqual(process.code, 0, "Build returned non-zero exit code")

		let project = try ProjectParser(path: Self.testPath, logLevel: .debug)
		var targets = Targets(for: project)

		let buildLog = try String(contentsOf: context.buildLog).components(separatedBy: .newlines)
		let logParser = XcodeLogParser(log: buildLog)

		try logParser.parse(&targets)

		let graph = DependencyGraphBuilder.build(targets: targets)
		let appTarget = try XCTUnwrap(targets.target(for: "App"), "Failed to get App target from targets")
		let app = try XCTUnwrap(graph.findNode(for: appTarget), "Failed to find App node in graph")

		// App should have two nodes - Framework & Common
		XCTAssertTrue(app.edges.count == 2, "App's edges is not equal to 2")
		_ = try XCTUnwrap(app.edges.first(where: { $0.to.name == "Framework" }), "Failed to get Framework edge from App")
		let commonEdge = try XCTUnwrap(app.edges.first(where: { $0.to.name == "Common" }), "Failed to get Common edge from App")

		let frameworkTarget = try XCTUnwrap(targets.target(for: "Framework"), "Failed to get Framework from targets")
		let framework = try XCTUnwrap(graph.findNode(for: frameworkTarget), "Failed to find Framework node in graph")

		// Framework should have two dependency edges - Common & SFSafeSymbols and one depender edge - App
		XCTAssertTrue(framework.edges.count == 3, "Framework's edges is not equal to 3")
		let symbolsEdge = try XCTUnwrap(framework.edges.first(where: { $0.to.name == "SFSafeSymbols" }), "Failed to get SFSafeSymbols edge from Framework")
		let frameworkCommonEdge = try XCTUnwrap(framework.edges.first(where: { $0.to.name == "Common" }), "Failed to get SFSafeSymbols edge from Framework")
		let frameworkAppEdge = try XCTUnwrap(framework.edges.first(where: { $0.to.name == "App" }), "Failed to get App edge from Framework")
		XCTAssertNotEqual(commonEdge, frameworkCommonEdge, "App's Common edge is equal to Framework's Common edge - they should have different from values")
		XCTAssertEqual(symbolsEdge.relationship, .dependency)
		XCTAssertEqual(frameworkCommonEdge.relationship, .dependency)
		XCTAssertEqual(frameworkAppEdge.relationship, .depender)
	}
}