//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import PackagePlugin

@main
struct KnitBuildPlugin: BuildToolPlugin {

    func createBuildCommands(
        context: PluginContext,
        target: any Target
    ) async throws -> [Command] {
        // This method is only invoked when the plugin is consumed by an SPM-only project
        fatalError("Unexpected project type. Please add plugin to an Xcode project.")
    }

}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension KnitBuildPlugin: XcodeBuildToolPlugin {
    
    func createBuildCommands(
        context: XcodePluginContext,
        target: XcodeTarget
    ) throws -> [Command] {
        guard let configFile = context.xcodeProject.filePaths.first(where: { path in
            path.lastComponent == "knitconfig.json"
        }) else {
            Diagnostics.error("No `knitconfig.json` file was found in the project.")
            return []
        }

        return [
            try context.makeBuildCommand(
                from: configFile,
                target: target
            )
        ]
    }

}

extension XcodePluginContext {

    func makeBuildCommand(
        from configFilePath: Path,
        target: XcodeTarget
    ) throws -> Command {
        let configFileData = try Data(contentsOf: URL(filePath: configFilePath.string))

        let config = try JSONDecoder().decode(KnitPluginConfig.self, from: configFileData)

        let typeSafetyOutputPath: Path?
        let unitTestOutputPath: Path?
        switch target.product?.kind {
        case .application:
            typeSafetyOutputPath = self.pluginWorkDirectory.appending("KnitDITypeSafety.swift")
            unitTestOutputPath = nil
        case .other("com.apple.product-type.bundle.unit-test"):
            typeSafetyOutputPath = nil
            unitTestOutputPath = self.pluginWorkDirectory.appending(subpath: "KnitDIRegistrationTests.swift")

        default:
            typeSafetyOutputPath = nil
            unitTestOutputPath = nil
        }

        let assemblyInputPaths = config.makeInputPaths(
            configFilePath: configFilePath
        )

        let assemblyInputArgs: [String] = assemblyInputPaths.flatMap { path in
            [
                "--assembly-input-path",
                path.string
            ]
        }

        let typeSafetyArgs: [String] = typeSafetyOutputPath.flatMap { path in
            [
                "--type-safety-extensions-output-path",
                path.string
            ]
        } ?? []

        let unitTestArgs: [String] = unitTestOutputPath.flatMap { path in
            [
                "--unit-test-output-path",
                path.string
            ]
        } ?? []

        let arguments: [String] =
            ["gen"] +
            assemblyInputArgs +
            typeSafetyArgs +
            unitTestArgs

        return .buildCommand(
            displayName: "Knit Plugin: Generate Knit files based on config \(configFilePath.description)",
            executable: try self.tool(named: "knit-cli").path,
            arguments: arguments,
            inputFiles: assemblyInputPaths,
            outputFiles: [typeSafetyOutputPath, unitTestOutputPath].compactMap { $0 }
        )
    }

}

#endif

/// Corresponds to the `knitconfig.json` file.
/// That JSON data will be decoded into a `KnitPluginConfig` instance.
struct KnitPluginConfig: Decodable {

    /// Corresponds the CLI argument of the same name.
    /// The strings should be file paths relative to the `knitconfig.json` file's location.
    let assemblyInputPaths: [String]

}

extension KnitPluginConfig {

    // Convert the relative path strings in the config to fully qualified `Path`s.
    func makeInputPaths(configFilePath: Path) -> [Path] {
        let basePath = configFilePath.removingLastComponent()
        return assemblyInputPaths.map { string in
            basePath.appending(subpath: string)
        }
    }

}
