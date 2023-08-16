//
//  GenCommand.swift
//  
//
//  Created by Brad Fol on 8/4/23.
//

import ArgumentParser
import KnitCodeGen
import Foundation
import SwiftSyntaxBuilder

struct GenCommand: ParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "gen",
        abstract: "Generate source files based on the parsed Assembly file."
    )

    @Option(help: """
                  Path to the file location in the current module where the Assembly source is located.
                  For example: `${PODS_TARGET_SRCROOT}/Sources/DI/ModuleNameAssembly.swift`
                  """)
    var assemblyInputPath: [String]

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

    public init() {}

    public func run() throws {
        let parsedConfig: ConfigurationSet
        do {
            parsedConfig = try parseAssemblies(at: assemblyInputPath)
            if let jsonDataOutputPath {
                let data = try JSONEncoder().encode(parsedConfig.assemblies)
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