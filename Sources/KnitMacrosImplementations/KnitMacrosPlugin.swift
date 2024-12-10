//
// Copyright © Block, Inc. All rights reserved.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct KnitMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ResolvableMacro.self
    ]
}
