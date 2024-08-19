//  Created by Alex Skorulis on 10/4/2024.

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

/// Source code defining a KnitModule implementation for module configurations
public enum KnitModuleSourceFile {
    
    public static func make(
        configurations: [Configuration],
        dependencies: [String]
    ) throws -> SourceFileSyntax {
        guard let firstConfig = configurations.first else {
            throw Error.noAssemblies
        }
        let moduleName = firstConfig.moduleName
        return try SourceFileSyntax {
            makeTypeDefinition(moduleName: firstConfig.moduleName, configurations: configurations, dependencies: dependencies)
            for configuration in configurations {
                try makeGeneratedAssembly(configuration: configuration, moduleName: moduleName)
            }
        }
    }

    private static func makeTypeDefinition(
        moduleName: String,
        configurations: [Configuration],
        dependencies: [String]
    ) -> EnumDeclSyntax {
        let assemblyNames = configurations.map { $0.assemblyName }
        return EnumDeclSyntax(
            modifiers: [
                DeclModifierSyntax(name: TokenSyntax(.keyword(.public), presence: .present))
            ],
            name: "\(raw: moduleName)_KnitModule: KnitModule"
        ) {
            makeAssembliesVar(assemblyNames: assemblyNames)
            makeDependenciesVar(modules: dependencies)
        }
    }

    private static func makeDependenciesVar(modules: [String]) -> VariableDeclSyntax {
        let moduleTypes = modules.map { "\($0)_KnitModule.self" }
        let accessorBlock = AccessorBlockSyntax.arrayAccessor(elements: moduleTypes)

        return VariableDeclSyntax.makeVar(
            keywords: [.public, .static],
            name: "moduleDependencies",
            type: "[KnitModule.Type]",
            accessorBlock: accessorBlock
        )
    }

    private static func makeAssembliesVar(assemblyNames: [String]) -> VariableDeclSyntax {
        let accessorBlock = AccessorBlockSyntax.arrayAccessor(elements: assemblyNames.map { "\($0).self" })

        return VariableDeclSyntax.makeVar(
            keywords: [.public, .static],
            name: "assemblies",
            type: "[any ModuleAssembly.Type]",
            accessorBlock: accessorBlock
        )
    }

    private static func makeGeneratedAssembly(configuration: Configuration, moduleName: String) throws -> ExtensionDeclSyntax {
        let accessorBlock = AccessorBlockSyntax(
            accessors: .getter(.init(stringLiteral: "\(moduleName)_KnitModule.allAssemblies"))
        )
        // Don't conform FakeAssembly to GeneratedModuleAssembly to prevent conflicting implementations of `dependencies`
        let conformance = configuration.assemblyType != .fakeAssembly ? ": GeneratedModuleAssembly" : ""
        return try ExtensionDeclSyntax("extension \(raw: configuration.assemblyName)\(raw: conformance)") {
            VariableDeclSyntax.makeVar(
                keywords: [.public, .static],
                name: "generatedDependencies",
                type: "[any ModuleAssembly.Type]",
                accessorBlock: accessorBlock
            )
        }
    }
}

// MARK: -

extension KnitModuleSourceFile {
    enum Error: LocalizedError {
        case noAssemblies

        var errorDescription: String? {
            switch self {
            case .noAssemblies:
                return "Attempting to generate a KnitModule without any Configurations"
            }
        }
    }
}
