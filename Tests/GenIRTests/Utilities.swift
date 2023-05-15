import Foundation

struct Utilities {
	static func basePath() -> URL {
		URL(fileURLWithPath: #file.replacingOccurrences(of: "Tests/GenIRTests/Utilities.swift", with: ""))
	}

	static func assetsPath() -> URL {
		basePath().appendingPathComponent("TestAssets")
	}
}
