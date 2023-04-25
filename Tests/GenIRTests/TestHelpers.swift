import Foundation

func baseTestingPath() -> URL {
	// HACK: use the #file magic to get a path to the test case... Maybe there's a better way to do this?
	URL(fileURLWithPath: #file.replacingOccurrences(of: "Tests/GenIRTests/TestHelpers.swift", with: ""))
}
