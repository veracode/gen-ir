// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "PIF",
	platforms: [.macOS(.v12)],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "PIFSupport",
			targets: ["PIFSupport"]
		)
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "PIFSupport",
			dependencies: [
				.product(name: "Logging", package: "swift-log")
			]
		),
		.testTarget(
			name: "PIFSupportTests",
			dependencies: ["PIFSupport"]
		),
		.testTarget(
			name: "PIFTests",
			dependencies: ["PIFSupport"],
			path: "PIF/Tests/PIFTests"
		),
		.executableTarget(
			name: "pif-parser",
			dependencies: [
				"PIFSupport"
			]
		)
	]
)
