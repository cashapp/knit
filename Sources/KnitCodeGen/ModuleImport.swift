//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
@preconcurrency import SwiftSyntax

public struct ModuleImport: Sendable {
    let decl: ImportDeclSyntax
    let ifConfigCondition: ExprSyntax?
    let name: String

    // To protect performance this should not be computed as it will be read potentially many times
    let isTestable: Bool

    init(decl: ImportDeclSyntax, ifConfigCondition: ExprSyntax? = nil) {
        self.decl = decl
        self.ifConfigCondition = ifConfigCondition
        self.name = decl.path.description
        self.isTestable = decl.attributes.contains { element in
            switch element {
            case .attribute(let attribute):
                return attribute.attributeName.trimmed.description == "testable"

            case .ifConfigDecl:
                return false
            }
        }
    }

    var description: String {
        return decl.description
    }

    // MARK: - Static Make Conveniences

    static func named(_ name: String) -> ModuleImport {
        let decl = ImportDeclSyntax(
            importKeyword: .keyword(.import, trailingTrivia: .space),
            path: [ImportPathComponentSyntax(name: .identifier(name))]
        )
        return ModuleImport(decl: decl)
    }

    static func testable(name: String) -> ModuleImport {
        let decl = try! ImportDeclSyntax("@testable import \(raw: name)")
        return ModuleImport(decl: decl)
    }
}

/// Set that allows inserting import statements to prevent duplicates.
/// Inserting a @testable import will replace the existing non testable import.
public struct ModuleImportSet {
    private var imports: [ModuleImport] = []

    init(imports: [ModuleImport]) {
        imports.forEach { insert($0) }
    }
    
    /// Inserting a @testable import will replace the existing non testable import.
    mutating func insert(_ imp: ModuleImport) {
        if let existingIndex = imports.firstIndex(where: { $0.name == imp.name}) {
            if imp.isTestable {
                imports[existingIndex] = imp
            }
        } else {
            imports.append(imp)
        }
    }

    mutating func insert(contentsOf newElements: [ModuleImport]) {
        newElements.forEach { insert($0) }
    }

    /// Imports sorted by name
    var sorted: [ModuleImport] {
        return imports.sorted { import1, import2 in
            return import1.name < import2.name
        }
    }
}
