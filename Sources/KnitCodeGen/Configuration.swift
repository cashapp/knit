import Foundation
import SwiftSyntax

public struct Configuration {

    /// Name of the module for this configuration.
    public var name: String

    public var registrations: [Registration]

    public var imports: [ImportDeclSyntax]

    public var testConfiguration: TestConfiguration?

    public init(
        name: String,
        registrations: [Registration],
        imports: [ImportDeclSyntax] = [],
        testConfiguration: TestConfiguration? = nil
    ) {
        self.name = name
        self.registrations = registrations
        self.imports = imports
        self.testConfiguration = testConfiguration
    }

}

public extension Configuration {

    func makeTypeSafetySourceFile() throws -> SourceFileSyntax {
        var allImports = imports

        allImports.append(ImportDeclSyntax(DeclSyntax("import Swinject"))!)
        return try TypeSafetySourceFile.make(
            assemblyName: "\(name)Assembly",
            imports: sortImports(allImports),
            extensionTarget: "Resolver",
            registrations: registrations
        )
    }

    func makeUnitTestSourceFile() throws -> SourceFileSyntax {
        var allImports = imports
        allImports.append(ImportDeclSyntax(DeclSyntax("@testable import \(raw: self.name)"))!)
        allImports.append(ImportDeclSyntax(DeclSyntax("import XCTest"))!)
        if let testImports = testConfiguration?.imports {
            let testImportsDecls = testImports.map { ImportDeclSyntax(DeclSyntax("import \(raw: $0)"))! }
            allImports.append(contentsOf: testImportsDecls)
        }

        return try UnitTestSourceFile.make(
            importDecls: sortImports(allImports),
            setupCodeBlock: testConfiguration?.testSetupCodeBlock,
            registrations: registrations
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
    ) throws {
        if let typeSafetyExtensionsOutputPath {
            write(
                sourceFile: try makeTypeSafetySourceFile(),
                to: typeSafetyExtensionsOutputPath
            )
        }

        if let unitTestOutputPath {
            write(
                sourceFile: try makeUnitTestSourceFile(),
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
