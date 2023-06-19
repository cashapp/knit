// Copyright © Square, Inc. All rights reserved.

import Foundation
import SwiftSyntax

// An error that is related to a piece of syntax
protocol SyntaxError {
    var syntax: SyntaxProtocol { get }
}
