//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax

public struct Configuration: Encodable {

    /// Name of the module for this configuration.
    public var assemblyName: String
    public let moduleName: String
    public var directives: KnitDirectives
    public var assemblyType: String

    public var registrations: [Registration]
    public var registrationsIntoCollections: [RegistrationIntoCollection]

    public var imports: [ModuleImport] = []
    public var targetResolver: String

    public init(
        assemblyName: String,
        moduleName: String,
        directives: KnitDirectives = .init(),
        assemblyType: String = "Assembly",
        registrations: [Registration],
        registrationsIntoCollections: [RegistrationIntoCollection],
        imports: [ModuleImport] = [],
        targetResolver: String
    ) {
        self.assemblyName = assemblyName
        self.directives = directives
        self.assemblyType = assemblyType
        self.registrations = registrations
        self.registrationsIntoCollections = registrationsIntoCollections
        self.imports = imports
        self.targetResolver = targetResolver
        self.moduleName = moduleName
    }

    public enum CodingKeys: CodingKey {
        case assemblyName
        case directives
        case assemblyType
        case registrations
    }
}

public extension Configuration {

    func makeTypeSafetySourceFile() throws -> SourceFileSyntax {
        return try TypeSafetySourceFile.make(
            assemblyName: assemblyName,
            extensionTarget: targetResolver,
            registrations: registrations
        )
    }

    func makeUnitTestSourceFile() throws -> SourceFileSyntax {
        return try UnitTestSourceFile.make(
            configuration: self
        )
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
