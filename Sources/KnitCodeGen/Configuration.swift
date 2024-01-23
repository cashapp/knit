import Foundation
import SwiftSyntax

public struct Configuration: Encodable {

    /// Name of the module for this configuration.
    public var name: String

    public var registrations: [Registration]
    public var registrationsIntoCollections: [RegistrationIntoCollection]

    public var imports: [ModuleImport] = []
    public var targetResolver: String

    public init(
        name: String,
        registrations: [Registration],
        registrationsIntoCollections: [RegistrationIntoCollection],
        imports: [ModuleImport] = [],
        targetResolver: String
    ) {
        self.name = name
        self.registrations = registrations
        self.registrationsIntoCollections = registrationsIntoCollections
        self.imports = imports
        self.targetResolver = targetResolver
    }

    public enum CodingKeys: CodingKey {
        case name
        case registrations
    }

}

public extension Configuration {

    func makeTypeSafetySourceFile() throws -> SourceFileSyntax {
        return try TypeSafetySourceFile.make(
            assemblyName: "\(name)Assembly",
            extensionTarget: targetResolver,
            registrations: registrations
        )
    }

    func makeUnitTestSourceFile() throws -> SourceFileSyntax {
        var allImports = imports
        allImports.append(try .testable(name: name))
        allImports.append(try .named("XCTest"))

        return try UnitTestSourceFile.make(
            configuration: self
        )
    }

    var assemblyName: String {
        "\(name)Assembly"
    }

}

func write(text: String, to path: String) {
    let data = text.data(using: .utf8)!
    let fileManager = FileManager.default
    // Write the file and mark as readonly
    let result = fileManager.createFile(
        atPath: path,
        contents: data,
        attributes: [.posixPermissions: 0o444]
    )
    if !result {
        fatalError("Could not write to \(path)")
    }
}

// MARK: - ImportDeclSyntax Convenience Init

public extension ImportDeclSyntax {

    init(moduleName: String) {
        self.init(
            path: [ 
                ImportPathComponentSyntax(
                    name: "\(raw: moduleName)"
                )
            ]
        )
    }

}
