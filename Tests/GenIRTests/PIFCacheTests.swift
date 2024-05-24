import XCTest
@testable import gen_ir
import PIFSupport

final class PIFCacheTests: XCTestCase {
	let testPath: URL = {
		TestContext.testAssetPath
			.appendingPathComponent("PIFCaches")
			.appendingPathComponent("SPMTest")
			.appendingPathComponent("SPMTest.xcodeproj")
	}()
	let scheme = "SPMTest"
	var cachePath: URL {
		testPath
			.deletingLastPathComponent()
			.appendingPathComponent("PIFCache")
	}

	func testSPMTestChain() throws {
		let context = TestContext()
		try context.build(test: testPath, scheme: scheme)
		let graph = context.graph

		let appTarget = try XCTUnwrap(context.targets.first(where: { $0.productName == "SPMTest.app" }))
		let node = try XCTUnwrap(graph.findNode(for: appTarget))

		XCTAssertEqual(node.edges.count, 2)
		let chain = graph.chain(for: appTarget)
		let nameSet = Set(chain.map { $0.value.name })

		let expectedNameSet = Set(["SPMTest", "MyLibrary", "MyCommonLibrary", "MyTransitiveLibrary"])
		let nameDifference = nameSet.symmetricDifference(expectedNameSet)
		XCTAssertTrue(nameDifference.isEmpty, "Difference found in name set (\(nameSet)) and expected name set: \(expectedNameSet) - difference: \(nameDifference)")
	}
}
