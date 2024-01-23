// Copyright © Square, Inc. All rights reserved.

@testable import KnitCodeGen
import SwiftSyntax
import XCTest

final class HeaderSourceFileTests: XCTestCase {

    func testBasicImports() {
        let imports: [ModuleImport] = [
            .named("ModuleA"),
            .named("ModuleB"),
        ]
        let header = HeaderSourceFile.make(
            imports: imports,
            comment: nil
        )
        let formattedResult = header.formatted().description

        let expected = #"""
        // Generated using Knit
        // Do not edit directly!

        import ModuleA
        import ModuleB
        """#
        XCTAssertEqual(formattedResult, expected)
    }

    func testIfConfigImports() throws {
        let imports: [ModuleImport] = [
            .init(decl: try ImportDeclSyntax("import ModuleA"), ifConfigCondition: ExprSyntax("SOME_FLAG")),
            .init(decl: try ImportDeclSyntax("import OtherModule"), ifConfigCondition: ExprSyntax("DEBUG")),
        ]

        let header = HeaderSourceFile.make(
            imports: imports,
            comment: nil
        )
        let formattedResult = header.formatted().description

        let expected = #"""
        // Generated using Knit
        // Do not edit directly!
        
        #if SOME_FLAG
        import ModuleA
        #endif
        #if DEBUG
        import OtherModule
        #endif
        
        """#
        XCTAssertEqual(formattedResult, expected)
    }

}

