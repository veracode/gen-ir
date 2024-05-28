import XCTest
@testable import gen_ir
@testable import DependencyGraph

final class DependencyGraphTests: XCTestCase {
	let testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("WorkspaceTest")
			.appendingPathComponent("Workspace.xcworkspace")
	}()
	let scheme = "App"

	func testChains() throws {
		// Test Setup
		let context = TestContext()
		let process = try context.build(test: testPath, scheme: scheme)
		XCTAssertEqual(process.code, 0, "Build returned non-zero exit code")

		let targets = context.targets
		let graph = context.graph

		let appTarget = try XCTUnwrap(targets.first(where: { $0.name == "App"}), "Failed to get App target from targets")
		let app = try XCTUnwrap(graph.findNode(for: appTarget), "Failed to find App node in graph")

		// App should have two nodes - Framework & Common
		XCTAssertTrue(app.edges.count == 2, "App's edges is not equal to 2")
		_ = try XCTUnwrap(app.edges.first(where: { $0.to.valueName == "Framework.framework" }), "Failed to get Framework edge from App")
		let commonEdge = try XCTUnwrap(app.edges.first(where: { $0.to.valueName == "Common.framework" }), "Failed to get Common edge from App")

		let frameworkTarget = try XCTUnwrap(targets.first(where: { $0.name ==  "Framework"}), "Failed to get Framework from targets")
		let framework = try XCTUnwrap(graph.findNode(for: frameworkTarget), "Failed to find Framework node in graph")

		// Framework should have two dependency edges - Common & SFSafeSymbols and one depender edge - App
		XCTAssertTrue(framework.edges.count == 3, "Framework's edges is not equal to 3")
		let symbolsEdge = try XCTUnwrap(framework.edges.first(where: { $0.to.valueName == "SFSafeSymbols.o" }), "Failed to get SFSafeSymbols edge from Framework")
		let frameworkCommonEdge = try XCTUnwrap(framework.edges.first(where: { $0.to.valueName == "Common.framework" }), "Failed to get SFSafeSymbols edge from Framework")
		let frameworkAppEdge = try XCTUnwrap(framework.edges.first(where: { $0.to.valueName == "App.app" }), "Failed to get App edge from Framework")

		XCTAssertNotEqual(commonEdge, frameworkCommonEdge, "App's Common edge is equal to Framework's Common edge - they should have different from values")
		XCTAssertEqual(symbolsEdge.relationship, .dependency)
		XCTAssertEqual(frameworkCommonEdge.relationship, .dependency)
		XCTAssertEqual(frameworkAppEdge.relationship, .depender)
	}
}
