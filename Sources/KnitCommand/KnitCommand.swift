import ArgumentParser
import KnitCodeGen
import Foundation
import SwiftSyntaxBuilder

// @main
public struct KnitCommand: ParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "knit",
        abstract: "Generate source files required for dependency injection",
        version: "0.0.1",
        shouldDisplay: false
    )

    @Option(help: """
                  Path to the file location in the current module where the Assembly source is located.
                  For example: `${PODS_TARGET_SRCROOT}/Sources/DI/ModuleNameAssembly.swift`
                  """)
    var assemblyInputPath: String

    @Option(help: """
                  Path to the file location in the current module where the unit test source should be written.
                  For example: `${PODS_TARGET_SRCROOT}/Sources/Generated/DITypeSafety.swift`
                  """)
    var typeSafetyExtensionsOutputPath: String?

    @Option(help: """
                  Path to the file location in the current module where the unit test source should be written.
                  For example: `${PODS_TARGET_SRCROOT}/UnitTests/Generated/RegistrationTests.swift`
                  """)
    var unitTestOutputPath: String?

    public init() {}

    public func run() {
        let parsedConfig: Configuration
        do {
            parsedConfig = try parseAssembly(at: assemblyInputPath)
            try parsedConfig.writeGeneratedFiles(
                typeSafetyExtensionsOutputPath: typeSafetyExtensionsOutputPath,
                unitTestOutputPath: unitTestOutputPath
            )
        } catch {
            fatalError(error.localizedDescription)
        }
    }

}
