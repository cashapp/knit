//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax

public struct ModuleImport {
    let decl: ImportDeclSyntax
    let ifConfigCondition: ExprSyntax?

    init(decl: ImportDeclSyntax, ifConfigCondition: ExprSyntax? = nil) {
        self.decl = decl
        self.ifConfigCondition = ifConfigCondition
    }

    var description: String {
        return decl.description
    }

    static func named(_ name: String) -> ModuleImport {
        let decl = try! ImportDeclSyntax("import \(raw: name)")
        return ModuleImport(decl: decl)
    }

    static func testable(name: String) -> ModuleImport {
        let decl = try! ImportDeclSyntax("@testable import \(raw: name)")
        return ModuleImport(decl: decl)
    }
}
