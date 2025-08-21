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
        let jsonFile = context.package.directoryURL.appending(path: "knitconfig.json")

        return [
            try KnitBuildPlugin.createCommand(
                type: .source,
                toolURL: try context.tool(named: "knit-cli").url,
                configFileURL: jsonFile,
                workingDirectory: context.pluginWorkDirectoryURL
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
        guard let configFile = context.xcodeProject.filePaths
            .map({ path in
                // The `context.xcodeProject` only exposes `filePaths`. Something like `fileURLs` is not yet available
                URL(filePath: path.string)
            })
            .first(where: { url in
                url.lastPathComponent == "knitconfig.json"
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
        from configFileURL: URL,
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
            toolURL: try self.tool(named: "knit-cli").url,
            configFileURL: configFileURL,
            workingDirectory: self.pluginWorkDirectoryURL
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
        toolURL: URL,
        configFileURL: URL,
        workingDirectory: URL
    ) throws -> Command {
        let configFileData = try Data(contentsOf: configFileURL)
        let config = try JSONDecoder().decode(KnitPluginConfig.self, from: configFileData)
        let assemblyInputURLs = config.makeInputURLs(
            configFileURL: configFileURL
        )
        
        let typeSafetyOutputURL: URL?
        let unitTestOutputURL: URL?
        switch type {
        case .source:
            typeSafetyOutputURL = workingDirectory.appending(path: "KnitDITypeSafety.swift")
            unitTestOutputURL = nil
        case .tests:
            typeSafetyOutputURL = nil
            unitTestOutputURL = workingDirectory.appending(path: "KnitDIRegistrationTests.swift")
        case .unknown:
            typeSafetyOutputURL = nil
            unitTestOutputURL = nil
        }
        
        let assemblyInputArgs: [String] = assemblyInputURLs.flatMap { url in
            [
                "--assembly-input-path",
                url.droppingScheme()
            ]
        }

        let typeSafetyArgs: [String] = typeSafetyOutputURL.flatMap { url in
            [
                "--type-safety-extensions-output-path",
                url.droppingScheme()
            ]
        } ?? []

        let unitTestArgs: [String] = unitTestOutputURL.flatMap { url in
            [
                "--unit-test-output-path",
                url.droppingScheme()
            ]
        } ?? []

        let arguments: [String] =
            ["gen"] +
            assemblyInputArgs +
            typeSafetyArgs +
            unitTestArgs

        return .buildCommand(
            displayName: "Knit Plugin: Generate Knit files based on config \(configFileURL.description). Output folder: \(workingDirectory.description)",
            executable: toolURL,
            arguments: arguments,
            inputFiles: assemblyInputURLs,
            outputFiles: [typeSafetyOutputURL, unitTestOutputURL].compactMap { $0 }
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

    // Convert the relative path strings in the config to fully qualified `URL`s.
    func makeInputURLs(configFileURL: URL) -> [URL] {
        let basePath = configFileURL.deletingLastPathComponent()
        return assemblyInputPaths.map { string in
            basePath.appending(path: string)
        }
    }

}

extension URL {

    func droppingScheme() -> String {
       path(percentEncoded: false)
    }

}
