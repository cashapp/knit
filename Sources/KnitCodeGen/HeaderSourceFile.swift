// Copyright © Square, Inc. All rights reserved.

import Foundation
import SwiftSyntax

/// Generate the shared headers for source files
public enum HeaderSourceFile {

    public static func make(
        imports: [ModuleImport],
        comment: String?
    ) -> SourceFileSyntax {
        let trivia = comment.map {
            Trivia(pieces: [
                .newlines(2),
                .blockComment($0)
            ])
        }

        return SourceFileSyntax(
            leadingTrivia: TriviaProvider.headerTrivia,
            statementsBuilder:  {
                for moduleImport in imports {
                    importDecl(moduleImport: moduleImport)
                }
            },
            trailingTrivia: trivia
        )
    }

    private static func importDecl(moduleImport: ModuleImport) -> DeclSyntaxProtocol {
        // Wrap the output in an #if where needed
        guard let ifConfigCondition = moduleImport.ifConfigCondition else {
            return moduleImport.decl
        }
        let codeBlock = CodeBlockItemListSyntax([.init(item: .init(moduleImport.decl))])
        let clause = IfConfigClauseSyntax(
            poundKeyword: .poundIfToken(),
            condition: ifConfigCondition,
            elements: .statements(codeBlock)
        )
        return IfConfigDeclSyntax(clauses: [clause])
    }
}
