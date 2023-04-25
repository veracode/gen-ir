import XCTest
@testable import gen_ir
import PBXProjParser

final class UmbrellaTests: XCTestCase {
	func tesUmbrellaTargets() throws {
		// TODO: Swift isn't picking this up - investigate why this stupid tool barely works...
		let umbrellaPath = baseTestingPath()
			.appendingPathComponent("TestAssets")
			.appendingPathComponent("Umbrella")
			.appendingPathComponent("Umbrella.xcworkspace")

		let projectParser = try ProjectParser(path: umbrellaPath, logLevel: .debug)
		let targets = Targets(for: projectParser)

		print("targets: \(targets)")
	}
}
