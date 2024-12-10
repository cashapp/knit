//  Created by Alexander Skorulis on 28/3/2024.

import KnitMacrosImplementations
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(KnitMacrosImplementations)
import KnitMacrosImplementations

let testMacros: [String: Macro.Type] = [
    "Resolvable": ResolvableMacro.self
]
#endif

final class ResolvableTests: XCTestCase {
    func test_macro_expansion() throws {
        assertMacroExpansion(
            """
            @Resolvable<Resolver>
            init(arg1: String, arg2: Int) {}
            """,
            expandedSource: """
            
            init(arg1: String, arg2: Int) {}

            static func make(resolver: Resolver) -> Self {
                 return .init(
                     arg1: resolver.string(),
                     arg2: resolver.int()
                 )
            }
            """,
            macros: testMacros
        )
    }
    
    func test_closure_param() throws {
        assertMacroExpansion(
            """
            @Resolvable<CustomResolver>
            init(closure: @escaping () -> Void) {}
            """,
            expandedSource: """
            
            init(closure: @escaping () -> Void) {}

            static func make(resolver: CustomResolver) -> Self {
                 return .init(
                     closure: resolver.closure()
                 )
            }
            """,
            macros: testMacros
        )
    }
    
    func test_default_param() throws {
        assertMacroExpansion(
            """
            @Resolvable<Resolver>
            init(value: Int = 5) {}
            """,
            expandedSource: """
            
            init(value: Int = 5) {}

            static func make(resolver: Resolver) -> Self {
                 return .init(
                     value: 5
                 )
            }
            """,
            macros: testMacros
        )
    }
    
    func test_argument() throws {
        assertMacroExpansion(
            """
            @Resolvable<Resolver>(arguments: ["value"])
            init(value: Int) {}
            """,
            expandedSource: """
            
            init(value: Int) {}

            static func make(resolver: Resolver, value: Int) -> Self {
                 return .init(
                     value: value
                 )
            }
            """,
            macros: testMacros
        )
    }
    
    func test_named() throws {
        assertMacroExpansion(
            """
            @Resolvable<Resolver>(names: ["value": "customName"])
            init(value: Int) {}
            """,
            expandedSource: """
            
            init(value: Int) {}

            static func make(resolver: Resolver) -> Self {
                 return .init(
                     value: resolver.int(name: .customName)
                 )
            }
            """,
            macros: testMacros
        )
    }
    
    func test_unused_argument() throws {
        assertMacroExpansion(
            """
            @Resolvable<Resolver>(arguments: ["param1"])
            init(value: Int) {}
            """,
            expandedSource: """
            
            init(value: Int) {}
            """,
            diagnostics: [
                .init(message: "Argument: 'param1' was declared but is not a parameter", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }
    
    func test_unused_name() throws {
        assertMacroExpansion(
            """
            @Resolvable<Resolver>(names: ["param1": "test])
            init(value: Int) {}
            """,
            expandedSource: """
            
            init(value: Int) {}
            """,
            diagnostics: [
                .init(message: "Name: 'param1' was declared but is not a parameter", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }
    
    func test_apply_static() throws {
        assertMacroExpansion(
            """
            @Resolvable<Resolver>
            static func makeThing(value: Int) -> Thing {
                Thing(value: value)
            }
            """,
            expandedSource: """
            
            static func makeThing(value: Int) -> Thing {
                Thing(value: value)
            }
            
            static func make(resolver: Resolver) -> Thing {
                 return makeThing(
                     value: resolver.int()
                 )
            }
            """,
            macros: testMacros
        )
    }
    
    func test_non_static_function() throws {
        assertMacroExpansion(
            """
            @Resolvable<Resolver>
            func makeThing(value: Int) -> Thing { .init() }
            """,
            expandedSource: """
            
            func makeThing(value: Int) -> Thing { .init() }
            """,
            diagnostics: [
                .init(
                    message: "@Resolvable can only be used on init declarations or static functions",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }
}
