//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax

// An error that is related to a piece of syntax
protocol SyntaxError: Error {
    var syntax: SyntaxProtocol { get }

    /// Report the error position on the line above the syntax node.
    var positionAboveNode: Bool { get }
}
