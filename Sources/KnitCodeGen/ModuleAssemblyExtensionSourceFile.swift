//
//  ModuleAssemblyExtensionSourceFile.swift
//  
//
//  Created by Brad Fol on 8/4/23.
//

import SwiftSyntax
import SwiftSyntaxBuilder

public enum ModuleAssemblyExtensionSourceFile {

    public static func make(
        currentModuleName: String,
        dependencyModuleNames: [String],
        additionalAssemblies: [String]
    ) throws -> SourceFileSyntax {
        return try SourceFileSyntax(leadingTrivia: TriviaProvider.headerTrivia) {
            DeclSyntax("import Knit")
            for dependencyModuleName in dependencyModuleNames where !dependencyModuleName.hasSuffix("Assembly") {
                DeclSyntax("import \(raw: dependencyModuleName)")
            }

            try ExtensionDeclSyntax("extension \(raw: currentModuleName)Assembly: GeneratedModuleAssembly") {

                // `public static var generatedDependencies: [any ModuleAssembly.Type]`
                VariableDeclSyntax(
                    modifiers: [
                        DeclModifierSyntax(name: TokenSyntax(.keyword(.public), presence: .present)),
                        DeclModifierSyntax(name: TokenSyntax(.keyword(.static), presence: .present)),
                    ],
                    bindingSpecifier: .keyword(.var),
                    bindingsBuilder: {
                        PatternBindingSyntax(
                            pattern: IdentifierPatternSyntax(identifier: .identifier("generatedDependencies")),
                            typeAnnotation: TypeAnnotationSyntax(type: "[any ModuleAssembly.Type]" as TypeSyntax),
                            accessorBlock: AccessorBlockSyntax(
                                
                                // Make the computed property accessor
                                accessors: .getter(.init(
                                    itemsBuilder: {
                                        let elements = ArrayElementListSyntax {
                                            // Turn each module name string into a meta type of the Assembly
                                            for name in (dependencyModuleNames + additionalAssemblies) {
                                                ArrayElementSyntax(
                                                    leadingTrivia: [ .newlines(1) ],
                                                    expression: "\(raw: typeName(name)).self" as ExprSyntax
                                                )
                                            }
                                        }

                                        ArrayExprSyntax(elements: elements)
                                    }
                                ))
                            )
                        )
                    }
                )
            }
        }
    }

    private static func typeName(_ name: String) -> String {
        if name.hasSuffix("Assembly") {
            return name
        }
        return "\(name)Assembly"
    }
}
