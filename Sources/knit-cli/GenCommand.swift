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
                  For example: `${PODS_TARGET_SRCROOT}/Sources/DI/ModuleNameAssembly.swift`.
                  If a directory is provided all filed ending in `Assembly.swift` files will be parsed
                  """)
    var assemblyInputPath: [String]

    @Option(help: """
                  Paths to assemblies external to the current module which should also be parsed.
                  Tests will be generated for these assemblies.
                  If a directory is provided all filed ending in `Assembly.swift` files will be parsed
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
                  Path to the file location in the current module where the KnitModule definition should be written.
                  For example: `${PODS_TARGET_SRCROOT}/Sources/Generated/KnitDITypeSafety.swift`
                  """)
    var knitModuleOutputPath: String?

    @Option(help: """
                  Path to the file location where the intermediate parsed data should be written
                  """)
    var jsonDataOutputPath: String?

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
            let expandedAssemblyPaths = try assemblyInputPath.flatMap { try expandInputPath(path: $0) }
            let expandedTestingPaths = try externalTestingAssemblies.flatMap { try expandInputPath(path: $0) }

            let assemblyParser = try AssemblyParser(
                moduleNameRegex: moduleNameRegex
            )
            parsedConfig = try assemblyParser.parseAssemblies(
                at: expandedAssemblyPaths,
                externalTestingAssemblies: expandedTestingPaths,
                moduleDependencies: dependencyModuleNames
            )

            try parsedConfig.validateNoDuplicateRegistrations()

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
    
    // Expand directory file paths to the assembly paths contained in the directory
    private func expandInputPath(path: String) throws -> [String] {
        let fileManager: FileManager = .default
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw Error.invalidPath(path)
        }
        if !isDirectory.boolValue {
            return [path]
        }
        let contents = try fileManager.contentsOfDirectory(atPath: path)
            .filter { $0.hasSuffix("Assembly.swift") }
        let dirURL = URL(fileURLWithPath: path)
        return contents.map { dirURL.appendingPathComponent($0).pathComponents.joined(separator: "/") }
    }
    
}

private extension GenCommand {
    enum Error: LocalizedError {
        case invalidPath(String)

        var errorDescription: String? {
            switch self {
            case let .invalidPath(path):
                return "Assembly path does not exist: \(path)"
            }
        }
    }
}
