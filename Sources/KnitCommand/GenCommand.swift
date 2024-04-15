//
// Copyright © Block, Inc. All rights reserved.
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
                  Paths to assemblies external to the current module which should also be parsed.
                  Tests will be generated for these assemblies
                  """)
    var externalTestingAssemblies: [String] = []

    @Option(help: """
                    An array of string arguments for the name of each module dependency.
                    If none are provided a file will still be written to the outputPath.
                    If the module name ends in "Assembly" it will be treated as an additional assembly.
                    """)
    var dependencyModuleNames = [String]()

    @Option(help: """
                  Path to the file location in the current module where the resolver type safety source should be written.
                  For example: `${PODS_TARGET_SRCROOT}/Sources/Generated/KnitDITypeSafety.swift`
                  """)
    var typeSafetyExtensionsOutputPath: String?

    @Option(help: """
                  Path to the file location in the current module where the unit test source should be written.
                  For example: `${PODS_TARGET_SRCROOT}/UnitTests/Generated/KnitDIRegistrationTests.swift`
                  """)
    var unitTestOutputPath: String?

    @Option(help: """
                  Path to the file location in the current module where the KnitModule defintion should be written.
                  For example: `${PODS_TARGET_SRCROOT}/Sources/Generated/KnitDITypeSafety.swift`
                  """)
    var knitModuleOutputPath: String?

    @Option(help: """
                  Path to the file location where the intermediate parsed data should be written
                  """)
    var jsonDataOutputPath: String?

    // This flag was added to allow backwards compatibility. This may prove to be unnecessary.
    @Flag(help: "When parsing assembly files, generate type safe methods against the target resolver")
    var useTargetResolver: Bool = false

    @Option(help: "Default type to extend when generating Resolver type safety methods")
    var defaultExtensionTargetResolver = "Resolver"

    @Option(help: """
                  Regex used to determine the module name of an assembly based on the filepath.
                  The regex must contain a single capture group which is the name of the module.
                  Assemblies can also use module-name("ABC") if file paths are not consistent
                  """)
    var moduleNameRegex: String?

    public init() {}

    public func run() throws {
        let parsedConfig: ConfigurationSet
        do {
            let assemblyParser = try AssemblyParser(
                defaultTargetResolver: defaultExtensionTargetResolver,
                useTargetResolver: useTargetResolver,
                moduleNameRegex: moduleNameRegex)
            parsedConfig = try assemblyParser.parseAssemblies(
                at: assemblyInputPath,
                externalTestingAssemblies: externalTestingAssemblies,
                moduleDependencies: dependencyModuleNames
            )
            if let jsonDataOutputPath {
                let data = try JSONEncoder().encode(parsedConfig.allAssemblies)
                try data.write(to: URL(fileURLWithPath: jsonDataOutputPath))
            }
        } catch {
            print(error.localizedDescription)
            throw ExitCode(1)
        }

        try parsedConfig.writeGeneratedFiles(
            typeSafetyExtensionsOutputPath: typeSafetyExtensionsOutputPath,
            unitTestOutputPath: unitTestOutputPath,
            knitModuleOutputPath: knitModuleOutputPath
        )
    }

}
