//
//  ModuleDependenciesCommand.swift
//  
//
//  Created by Brad Fol on 8/4/23.
//

import ArgumentParser
import KnitCodeGen

struct ModuleDependenciesCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "module-deps",
        abstract: "Write a ModuleAssembly extension file with the DI dependencies for that module."
    )

    @Option(help: """
                  The name of the current module where the output source file will be included.
                  """)
    var currentModuleName: String

    @Option(help: """
                  Write the generated ModuleAssembly extension source file to the provided path.
                  """)
    var outputPath: String

    @Argument(help: """
                    An array of string arguments for the name of each module dependency.
                    If none are provided a file will still be written to the outputPath.
                    """)
    var dependencyModuleNames = [String]()

    func run() throws {
        let result = ModuleAssemblyExtensionSourceFile.make(
            currentModuleName: currentModuleName,
            dependencyModuleNames: dependencyModuleNames
        )

        result.write(to: outputPath)
    }

}
