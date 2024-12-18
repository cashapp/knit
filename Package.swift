// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Knit",
    platforms: [
        .macOS(.v14),
        .iOS(.v15),
    ],
    products: [
        .library(name: "Knit", targets: ["Knit"]),
        .plugin(name: "KnitBuildPlugin", targets: ["KnitBuildPlugin"]),
        .executable(name: "knit-cli", targets: ["knit-cli"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.2"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "Knit",
            dependencies: [
                .target(name: "Swinject"),
                .target(name: "SwinjectAutoregistration"),
            ],
            exclude: ["ServiceCollection/Container+ServiceCollection.erb"]
        ),
        .testTarget(
            name: "KnitTests",
            dependencies: [
                .target(name: "Knit"),
            ]
        ),
        .plugin(
            name: "KnitBuildPlugin",
            capability: .buildTool,
            dependencies: [
                .target(name: "knit-cli"),
            ]
        ),

        // MARK: - Swinject
        .target(
            name: "Swinject",
            exclude: ["Container.Arguments.erb", "Resolver.erb", "ServiceEntry.TypeForwarding.erb"]
        ),
        .target(
            name: "SwinjectAutoregistration",
            dependencies: [
                .target(name: "Swinject"),
            ]
        ),
        .testTarget(
            name: "SwinjectTests",
            dependencies: [
                .target(name: "Swinject"),
            ]
        ),
        .testTarget(
            name: "SwinjectAutoregistrationTests",
            dependencies: [
                .target(name: "SwinjectAutoregistration"),
            ]
        ),

        // MARK: - CLI
        .executableTarget(
            name: "knit-cli",
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
            name: "KnitCodeGenTests",
            dependencies: [
                "KnitCodeGen",
            ]
        ),
    ],
    swiftLanguageVersions: [
        // When this SPM package is imported by a Swift 6 toolchain it should still be used in the v5 language mode
        .v5,
    ]
)
