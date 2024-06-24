// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Knit",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "Knit", targets: ["Knit"]),
        .executable(name: "knit-cli", targets: ["KnitCommand"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.2"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0"),
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.9.1"),
        .package(url: "https://github.com/Swinject/SwinjectAutoregistration.git", from: "2.8.4"),
    ],
    targets: [
        .target(
            name: "Knit",
            dependencies: [
                .product(name: "Swinject", package: "Swinject"),
                .product(name: "SwinjectAutoregistration", package: "SwinjectAutoregistration"),
            ]
        ),
        .executableTarget(
            name: "KnitCommand",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "KnitCodeGen"),
            ]
        ),
        .target(
            name: "KnitCodeGen",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "KnitTests",
            dependencies: [
                "Knit",
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
