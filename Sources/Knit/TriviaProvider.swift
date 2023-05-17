//
// Copyright © Square, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax

struct TriviaProvider {
    static var headerTrivia: Trivia {
        return Trivia(pieces: [
            .blockComment(headerText)
        ])
    }

    private static var headerText: String {
        return """
            // Generated using SwiftSyntax
            // Do not edit directly!

            //
            // Copyright © Square, Inc. All rights reserved.
            //

            """
    }
}
