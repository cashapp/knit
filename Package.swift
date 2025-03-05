// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Knit",
    platforms: [
        .macOS(.v14),
        .iOS(.v15),
    ],
    products: [
        .library(name: "Knit", targets: ["Knit"]),
        .library(name: "KnitMacros", targets: ["KnitMacros"] ),
        .library(name: "KnitTesting", targets: ["KnitTesting"]),
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
            ]
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
        .target(
            name: "KnitTesting",
            dependencies: [
                .target(name: "Swinject"),
                .target(name: "Knit"),
            ]
        ),

        // MARK: - Swinject
        .target(
            name: "Swinject",
            exclude: ["Container.Arguments.erb", "Resolver.erb", "ServiceEntry.TypeForwarding.erb"]
        ),
        .testTarget(
            name: "SwinjectTests",
            dependencies: [
                .target(name: "Swinject"),
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

        // MARK: - Macro
        .macro(
            name: "KnitMacrosImplementations",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .target(name: "KnitCodeGen"),
            ]
        ),
        .target(name: "KnitMacros", dependencies: ["KnitMacrosImplementations"]),
        .testTarget(
            name: "KnitMacrosTests",
            dependencies: [
                "KnitMacrosImplementations",
                .target(name: "KnitMacros"),
                .target(name: "KnitCodeGen"),
                .target(name: "Swinject"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),

    ],
    swiftLanguageVersions: [
        // When this SPM package is imported by a Swift 6 toolchain it should still be used in the v5 language mode
        .v5,
    ]
)
