//  Created by Alex Skorulis on 10/4/2024.

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

/// Source code defining a KnitModule implementation for module configurations
public enum KnitModuleSourceFile {
    
    public static func make(
        configurations: [Configuration]
    ) throws -> SourceFileSyntax {
        guard let firstConfig = configurations.first else {
            throw Error.noAssemblies
        }
        return SourceFileSyntax(leadingTrivia: TriviaProvider.headerTrivia) {
            DeclSyntax("import Knit")
            makeTypeDefinition(moduleName: firstConfig.moduleName, configurations: configurations)
        }
    }

    private static func makeTypeDefinition(
        moduleName: String,
        configurations: [Configuration]
    ) -> EnumDeclSyntax {
        let assemblyNames = configurations.map { $0.assemblyName }
        return EnumDeclSyntax(
            modifiers: [
                DeclModifierSyntax(name: TokenSyntax(.keyword(.public), presence: .present))
            ],
            name: "\(raw: moduleName)_KnitModule: KnitModule"
        ) {
            makeAssembliesVar(assemblyNames: assemblyNames)
        }
    }

    private static func makeAssembliesVar(assemblyNames: [String]) -> VariableDeclSyntax {
        let accessorBlock = AccessorBlockSyntax(
            accessors: .getter(.init(
                itemsBuilder: {
                    let elements = ArrayElementListSyntax {
                        for name in assemblyNames {
                            ArrayElementSyntax(
                                leadingTrivia: [ .newlines(1) ],
                                expression: "\(raw: name).self" as ExprSyntax
                            )
                        }
                    }

                    ArrayExprSyntax(elements: elements)
                }
            ))
        )

        return VariableDeclSyntax(
            modifiers: [
                DeclModifierSyntax(name: TokenSyntax(.keyword(.public), presence: .present)),
                DeclModifierSyntax(name: TokenSyntax(.keyword(.static), presence: .present)),
            ],
            bindingSpecifier: .keyword(.var),
            bindingsBuilder: {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("assemblies")),
                    typeAnnotation: TypeAnnotationSyntax(type: "[any ModuleAssembly.Type]" as TypeSyntax),
                    accessorBlock: accessorBlock
                )
            }
        )
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
