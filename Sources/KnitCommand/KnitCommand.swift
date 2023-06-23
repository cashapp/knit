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

    @Option(help: """
                  Path to the file location where the intermediate parsed data should be written
                  """)
    var jsonDataOutputPath: String?

    @Option(help: """
                  The name of the target type where the type-safe extensions will go.
                  """)
    var defaultResolverName: String = "Resolver"

    public init() {}

    public func run() throws {
        let parsedConfig: Configuration
        do {
            parsedConfig = try parseAssembly(at: assemblyInputPath, defaultResolverName: defaultResolverName)
            if let jsonDataOutputPath {
                let data = try JSONEncoder().encode(parsedConfig)
                try data.write(to: URL(fileURLWithPath: jsonDataOutputPath))
            }
        } catch {
            print(error.localizedDescription)
            throw ExitCode(1)
        }

        parsedConfig.writeGeneratedFiles(
            typeSafetyExtensionsOutputPath: typeSafetyExtensionsOutputPath,
            unitTestOutputPath: unitTestOutputPath
        )
    }

}
