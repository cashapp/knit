import ArgumentParser
import KnitCodeGen
import Foundation
import SwiftSyntaxBuilder

@main
public struct KnitCommand: ParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "gen",
        abstract: "Generate source files required for dependency injection"
    )

    @Option(help: """
                  Path to the file location in the current module where the Assembly source is located.
                  For example: `${PODS_TARGET_SRCROOT}/Sources/DI/ModuleNameAssembly.swift`
                  """)
    var assemblyInputPath: String

    @Option(help: """
                  Path to the file location in the current module where the unit test source should be written.
                  For example: `${PODS_TARGET_SRCROOT}/Sources/Generated/KnitDITypeSafety.swift`
                  """)
    var typeSafetyExtensionsOutputPath: String?

    @Option(help: """
                  Path to the file location in the current module where the unit test source should be written.
                  For example: `${PODS_TARGET_SRCROOT}/UnitTests/Generated/KnitDIRegistrationTests.swift`
                  """)
    var unitTestOutputPath: String?

    public init() {}

    public func run() {
        let parsedConfig: Configuration
        do {
            parsedConfig = try parseAssembly(at: assemblyInputPath)
        } catch {
            fatalError(error.localizedDescription)
        }

        parsedConfig.writeGeneratedFiles(
            typeSafetyExtensionsOutputPath: typeSafetyExtensionsOutputPath,
            unitTestOutputPath: unitTestOutputPath
        )
    }

}
