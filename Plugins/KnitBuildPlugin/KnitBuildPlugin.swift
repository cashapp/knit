//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import PackagePlugin

@main @available(macOS 13.0, *)
struct KnitBuildPlugin: BuildToolPlugin {

    func createBuildCommands(
        context: PluginContext,
        target: any Target
    ) async throws -> [Command] {
        let jsonFile = context.package.directory.appending(subpath: "knitconfig.json")
        
        return [
            try KnitBuildPlugin.createCommand(
                type: .source,
                toolPath: try context.tool(named: "knit-cli").path,
                configFilePath: jsonFile,
                workingDirectory: context.pluginWorkDirectory
            )
        ]
        
    }

}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

@available(macOS 13.0, *)
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
        let command: CommandType
        switch target.product?.kind {
        case .application:
            command = .source
        case .other("com.apple.product-type.bundle.unit-test"):
            command = .tests
        default:
            command = .unknown
        }
        
        return try KnitBuildPlugin.createCommand(
            type: command,
            toolPath: try self.tool(named: "knit-cli").path,
            configFilePath: configFilePath,
            workingDirectory: self.pluginWorkDirectory
        )
    }

}

#endif

fileprivate enum CommandType {
    case source, tests, unknown
}

@available(macOS 13.0, *)
extension KnitBuildPlugin {
    fileprivate static func createCommand(
        type: CommandType,
        toolPath: Path,
        configFilePath: Path,
        workingDirectory: Path
    ) throws -> Command {
        let configFileData = try Data(contentsOf: URL(filePath: configFilePath.string))
        let config = try JSONDecoder().decode(KnitPluginConfig.self, from: configFileData)
        let assemblyInputPaths = config.makeInputPaths(
            configFilePath: configFilePath
        )
        
        let typeSafetyOutputPath: Path?
        let unitTestOutputPath: Path?
        switch type {
        case .source:
            typeSafetyOutputPath = workingDirectory.appending("KnitDITypeSafety.swift")
            unitTestOutputPath = nil
        case .tests:
            typeSafetyOutputPath = nil
            unitTestOutputPath = workingDirectory.appending(subpath: "KnitDIRegistrationTests.swift")
        case .unknown:
            unitTestOutputPath = nil
            typeSafetyOutputPath = nil
        }
        
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
            displayName: "Knit Plugin: Generate Knit files based on config \(configFilePath.description). Output folder: \(workingDirectory.description)",
            executable: toolPath,
            arguments: arguments,
            inputFiles: assemblyInputPaths,
            outputFiles: [typeSafetyOutputPath, unitTestOutputPath].compactMap { $0 }
        )
    }
}

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
