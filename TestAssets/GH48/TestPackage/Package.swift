// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "TestPackage",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "TestPackage",
            targets: [
                "TestPackage"
            ]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "TestPackage",
            dependencies: [],
            resources: [],
            plugins: []
        )
    ]
)
