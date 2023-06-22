import Foundation
import SwiftSyntax

public struct Configuration: Encodable {

    /// Name of the module for this configuration.
    public var name: String

    public var registrations: [Registration]
    public var registrationsIntoCollections: [RegistrationIntoCollection]

    public var imports: [ImportDeclSyntax] = []

    public init(
        name: String,
        registrations: [Registration],
        registrationsIntoCollections: [RegistrationIntoCollection],
        imports: [ImportDeclSyntax] = []
    ) {
        self.name = name
        self.registrations = registrations
        self.registrationsIntoCollections = registrationsIntoCollections
        self.imports = imports
    }

    public enum CodingKeys: CodingKey {
        case name
        case registrations
    }

}

public extension Configuration {

    func makeTypeSafetySourceFile() -> SourceFileSyntax {
        var allImports = imports
        allImports.append("import Swinject")
        return TypeSafetySourceFile.make(
            assemblyName: "\(name)Assembly",
            imports: sortImports(allImports),
            extensionTarget: "Resolver",
            registrations: registrations
        )
    }

    func makeUnitTestSourceFile() -> SourceFileSyntax {
        var allImports = imports
        allImports.append("@testable import \(raw: self.name)")
        allImports.append("import XCTest")

        return UnitTestSourceFile.make(
            importDecls: sortImports(allImports),
            registrations: registrations,
            registrationsIntoCollections: registrationsIntoCollections
        )
    }

    func sortImports(_ imports: [ImportDeclSyntax]) -> [ImportDeclSyntax] {
        return imports.sorted { import1, import2 in
            let i1Name = import1.description.replacingOccurrences(of: "@testable ", with: "")
            let i2Name = import2.description.replacingOccurrences(of: "@testable ", with: "")
            return i1Name < i2Name
        }
    }

    func writeGeneratedFiles(
        typeSafetyExtensionsOutputPath: String?,
        unitTestOutputPath: String?
    ) {
        if let typeSafetyExtensionsOutputPath {
            write(
                sourceFile: makeTypeSafetySourceFile(),
                to: typeSafetyExtensionsOutputPath
            )
        }

        if let unitTestOutputPath {
            write(
                sourceFile: makeUnitTestSourceFile(),
                to: unitTestOutputPath
            )
        }
    }

}

func write(sourceFile: SourceFileSyntax, to path: String) {
    let data = sourceFile.formatted().description.data(using: .utf8)!

    let pathURL = URL(fileURLWithPath: path, isDirectory: false)

    do {
        try data.write(to: pathURL)
    } catch {
        fatalError("\(error)")
    }
}

// MARK: - ImportDeclSyntax Convenience Init

public extension ImportDeclSyntax {

    init(moduleName: String) {
        self.init(
            path: [ AccessPathComponentSyntax(name: moduleName) ]
        )
    }

}
