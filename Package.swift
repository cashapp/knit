// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Knit",
    platforms: [
        .macOS(.v12),
    ],
    products: [
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "508.0.1"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "KnitCommand",
            dependencies: [
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxParser", package: "swift-syntax"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "KnitCodeGen"),
            ]
        ),
        .target(
            name: "KnitCodeGen",
            dependencies: [
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "KnitCodeGenTests",
            dependencies: [
                "KnitCodeGen",
            ]
        ),
    ]
)
