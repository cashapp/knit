// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Knit",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(name: "KnitLibrary", targets: ["KnitCommand"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-syntax.git",
            revision: "edd2d0cdb988ac45e2515e0dd0624e4a6de54a94"
        ),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "KnitCommand",
            dependencies: [
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxParser", package: "swift-syntax"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "Knit"),
            ]
        ),
        .target(
            name: "Knit",
            dependencies: [
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "KnitTests",
            dependencies: [
                "Knit",
            ]
        ),
    ]
)
