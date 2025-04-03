// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "GenIR",
	platforms: [
		.macOS(.v12)
	],
	products: [
		.library(name: "DependencyGraph", targets: ["DependencyGraph"]),
		.library(name: "LogHandlers", targets: ["LogHandlers"]),
		.executable(name: "gen-ir", targets: ["gen-ir"])
	],
	dependencies: [
		// Dependencies declare other packages that this package depends on.
		// .package(url: /* package url */, from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
		.package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
		.package(path: "PIF")
	],
	targets: [
		// Targets are the basic building blocks of a package. A target can define a module or a test suite.
		// Targets can depend on other targets in this package, and on products in packages this package depends on.
		.target(
			name: "LogHandlers",
			dependencies: [
				.product(name: "Logging", package: "swift-log")
			]
		),
		.target(
			name: "DependencyGraph",
			dependencies: [
				.product(name: "Logging", package: "swift-log"),
				.target(name: "LogHandlers")
			]
		),
		.executableTarget(
			name: "gen-ir",
			dependencies: [
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
				.product(name: "Logging", package: "swift-log"),
				.product(name: "PIFSupport", package: "PIF"),
				.target(name: "DependencyGraph"),
				.target(name: "LogHandlers")
			],
			path: "Sources/GenIR"
		),
		.testTarget(
			name: "GenIRTests",
			dependencies: ["gen-ir"],
			path: "Tests/GenIRTests"
		)
	]
)
