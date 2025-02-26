//
// Copyright © Block, Inc. All rights reserved.
//

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
                    moduleImport.decl
                        .maybeWithCondition(ifConfigCondition: moduleImport.ifConfigCondition)
                }
            },
            trailingTrivia: trivia
        )
    }
}
