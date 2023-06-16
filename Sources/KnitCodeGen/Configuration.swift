import Foundation
import SwiftSyntax

public struct Configuration {

    /// Name of the module for this configuration.
    public var name: String

    public var registrations: [Registration]

    public var errors: [Error]

    public var imports: [ImportDeclSyntax]

    public var testConfiguration: TestConfiguration?

    public init(
        name: String,
        registrations: [Registration],
        errors: [Error],
        imports: [ImportDeclSyntax] = [],
        testConfiguration: TestConfiguration? = nil
    ) {
        self.name = name
        self.registrations = registrations
        self.errors = errors
        self.imports = imports
        self.testConfiguration = testConfiguration
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
        if let testImports = testConfiguration?.imports {
            let testImportsDecls = testImports.map { ImportDeclSyntax(moduleName: $0) }
            allImports.append(contentsOf: testImportsDecls)
        }

        return UnitTestSourceFile.make(
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
        // Output any errors that occurred during parsing
        for error in errors {
            // TODO: Add file and line numbers and turn into an error
            print("warning: \(error.localizedDescription)")
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
