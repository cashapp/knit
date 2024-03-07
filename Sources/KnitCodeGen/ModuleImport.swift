//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax

public struct ModuleImport {
    let decl: ImportDeclSyntax
    let ifConfigCondition: ExprSyntax?
    let name: String
    let isTestable: Bool

    init(decl: ImportDeclSyntax, ifConfigCondition: ExprSyntax? = nil) {
        self.decl = decl
        self.ifConfigCondition = ifConfigCondition
        let desc = decl.description
        self.name = String(desc.split(separator: " ").last!)
        self.isTestable = desc.hasPrefix("@testable")

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

/// Container that allows inserting import statements to prevent duplicates
/// Adding a @testable import will replace the existing non testable import
public struct ModuleImportSet {
    private var imports: [ModuleImport] = []

    init(imports: [ModuleImport]) {
        imports.forEach { insert($0) }
    }
    
    mutating func insert(_ imp: ModuleImport) {
        if let existingIndex = imports.firstIndex(where: { $0.name == imp.name}) {
            if imp.isTestable {
                imports[existingIndex] = imp
            }
        } else {
            imports.append(imp)
        }
    }
    
    /// Imports sorted by name
    var sorted: [ModuleImport] {
        return imports.sorted { import1, import2 in
            return import1.name < import2.name
        }
    }
}
