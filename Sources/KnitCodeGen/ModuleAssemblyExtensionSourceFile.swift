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
    ) -> SourceFileSyntax {
        return SourceFileSyntax(leadingTrivia: TriviaProvider.headerTrivia) {
            DeclSyntax("import Knit")
            for dependencyModuleName in dependencyModuleNames where !dependencyModuleName.hasSuffix("Assembly") {
                DeclSyntax("import \(raw: dependencyModuleName)")
            }

            ExtensionDeclSyntax("extension \(currentModuleName)Assembly: GeneratedModuleAssembly") {

                // `public static var generatedDependencies: [any ModuleAssembly.Type]`
                VariableDeclSyntax(
                    modifiers: [
                        DeclModifierSyntax(name: TokenSyntax(.publicKeyword, presence: .present)),
                        DeclModifierSyntax(name: TokenSyntax(.staticKeyword, presence: .present)),
                    ],
                    name: "generatedDependencies",
                    type: TypeAnnotationSyntax(type: "[any ModuleAssembly.Type]" as TypeSyntax),

                    // Make the computed property accessor
                    accessor: {
                        let elements = ArrayElementList {
                            // Turn each module name string into a meta type of the Assembly
                            for name in (dependencyModuleNames + additionalAssemblies) {
                                ArrayElementSyntax(
                                    leadingTrivia: [ .newlines(1) ],
                                    expression: "\(raw: typeName(name)).self" as MemberAccessExprSyntax
                                )
                            }
                        }

                        ArrayExpr(elements: elements)
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
