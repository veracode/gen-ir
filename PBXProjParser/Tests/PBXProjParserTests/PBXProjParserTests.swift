import XCTest
@testable import PBXProjParser

final class PBXProjParserTests: XCTestCase {
	func testDoubleTargetsHaveValidTargets() throws {
		let path = URL(fileURLWithPath:
			"Tests/PBXProjParserTests/TestAssets/Projects/DoubleTargetTest/DoubleTargetTest.xcworkspace"
		)

		let parser = try ProjectParser(path: path, logLevel: .debug)

		let targets = parser.targets
		let targetNames = targets.map { $0.name }

		let knownNames = ["DoubleTargetTest", "MyBundle", "Pods-DoubleTargetTest"]

		XCTAssert(targetNames.count == knownNames.count, "The list of targets doesn't match the size of allowed names")

		for name in targetNames {
			XCTAssert(knownNames.contains(name), "\(name) wasn't in knownNames: \(knownNames)")
		}
	}

	func testDoubleTargetsHaveValidDependencies() throws {
		let path = URL(fileURLWithPath:
			"Tests/PBXProjParserTests/TestAssets/Projects/DoubleTargetTest/DoubleTargetTest.xcworkspace"
		)

		let parser = try ProjectParser(path: path, logLevel: .debug)
		let dependencies = parser.targets.reduce(into: [String: [String]]()) { partialResult, target in
			partialResult[target.name] = parser.dependencies(for: target.name)
		}

		let knownDependencies = [
			// TODO: This should probably handle Cocoapods doing their stupid embedding thing without listing it as a dependency...
			"DoubleTargetTest": [],
			// TODO: should we also disregard Cocoapods doing their stupid bundle as a native target even though it isn't
			"MyBundle": ["MyBundle.bundle"],
			"Pods-DoubleTargetTest": ["MyBundle.framework", "MyBundle.bundle"],
			]

		XCTAssert(
			dependencies == knownDependencies,
			"Dependencies: \(dependencies) doesn't equal known dependencies: \(knownDependencies)"
		)
	}
}
