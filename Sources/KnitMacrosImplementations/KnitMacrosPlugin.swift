//  Created by Alexander Skorulis on 28/3/2024.

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct MacroFunPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ResolvableMacro.self
    ]
}
