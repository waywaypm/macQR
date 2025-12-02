// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "macQR",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "macQR",
            targets: ["macQR"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "macQR",
            dependencies: [],
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)
