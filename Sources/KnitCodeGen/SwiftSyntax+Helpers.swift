//
// Copyright © Block, Inc. All rights reserved.
//

import SwiftSyntax
import SwiftSyntaxBuilder

// Helpers to simplify common swift code patterns

extension AccessorBlockSyntax {
    
    /// Create an AccessorBlockSyntax for an array of values
    static func arrayAccessor(elements: [String]) -> AccessorBlockSyntax {
        AccessorBlockSyntax(
            accessors: .getter(.init(
                itemsBuilder: {
                    let elements = ArrayElementListSyntax {
                        for element in elements {
                            ArrayElementSyntax(
                                leadingTrivia: [ .newlines(1) ],
                                expression: "\(raw: element)" as ExprSyntax
                            )
                        }
                    }

                    ArrayExprSyntax(elements: elements)
                }
            ))
        )
    }
}

extension VariableDeclSyntax {

    static func makeVar(
        keywords: [Keyword],
        name: String,
        type: String,
        accessorBlock: AccessorBlockSyntax
    ) -> VariableDeclSyntax {
        let modifiers = keywords.map { DeclModifierSyntax(name: TokenSyntax(.keyword($0), presence: .present)) }
        return VariableDeclSyntax(
            modifiers: .init(modifiers),
            bindingSpecifier: .keyword(.var),
            bindingsBuilder: {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(name)),
                    typeAnnotation: TypeAnnotationSyntax(type: TypeSyntax(stringLiteral: type)),
                    accessorBlock: accessorBlock
                )
            }
        )
    }
}

extension DeclSyntaxProtocol {

    // Wrap the declaration in an #if where needed
    func maybeWithCondition(ifConfigCondition: ExprSyntax?) -> DeclSyntaxProtocol {
        guard let ifConfigCondition else {
            return self
        }
        let codeBlock = CodeBlockItemListSyntax([.init(item: .init(self))])
        let clause = IfConfigClauseSyntax(
            poundKeyword: .poundIfToken(),
            condition: ifConfigCondition,
            elements: .statements(codeBlock)
        )
        return IfConfigDeclSyntax(clauses: [clause])
    }
}
