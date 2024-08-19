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
        .library(name: "Knit", targets: ["Knit"])
    ],
    dependencies: [
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.9.1"),
        .package(url: "https://github.com/Swinject/SwinjectAutoregistration.git", from: "2.9.1"),
    ],
    targets: [
        .target(
            name: "Knit",
            dependencies: [
                .product(name: "Swinject", package: "Swinject"),
                .product(name: "SwinjectAutoregistration", package: "SwinjectAutoregistration"),
            ],
            exclude: ["ServiceCollection/Container+ServiceCollection.erb"]
        ),
        .testTarget(
            name: "KnitTests",
            dependencies: [
                "Knit",
            ]
        ),
    ]
)
