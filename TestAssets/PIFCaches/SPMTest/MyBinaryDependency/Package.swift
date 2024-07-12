// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let lottieXCFramework = Target.binaryTarget(
  name: "MyBinaryDependency",
  url: "https://github.com/airbnb/lottie-ios/releases/download/4.4.3/Lottie-Xcode-15.2.xcframework.zip",
  checksum: "546b7e718ed806646b84645ecfb1e1d6a65ac0387ff3f8ecb92dbaf2116cd62c")

let package = Package(
    name: "MyBinaryDependency",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MyBinaryDependency",
            targets: ["MyBinaryDependency"/*, "_Stub"*/]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        lottieXCFramework,
//        .target(name: "_Stub"),
    ]
)
