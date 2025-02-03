//
// Copyright © Block, Inc. All rights reserved.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MacroFunPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ResolvableMacro.self,
        ResolvableStructMacro.self,
    ]
}
