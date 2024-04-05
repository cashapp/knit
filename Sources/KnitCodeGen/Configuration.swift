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
    public var implements: [String]
    public var targetResolver: String

    public init(
        assemblyName: String,
        moduleName: String,
        directives: KnitDirectives = .init(),
        assemblyType: String = "Assembly",
        registrations: [Registration],
        registrationsIntoCollections: [RegistrationIntoCollection],
        imports: [ModuleImport] = [],
        implements: [String] = [],
        targetResolver: String
    ) {
        self.assemblyName = assemblyName
        self.directives = directives
        self.assemblyType = assemblyType
        self.registrations = registrations
        self.registrationsIntoCollections = registrationsIntoCollections
        self.imports = imports
        self.targetResolver = targetResolver
        self.implements = implements
        self.moduleName = moduleName
    }

    public enum CodingKeys: CodingKey {
        case assemblyName
        case directives
        case assemblyType
        case registrations
        case implements
    }

    // Testing all registrations introduces complications, limit what is tested for simplicity
    var registrationsCompatibleWithCompleteTests: [Registration] {
        return registrations
            // Filter out tests with arguments as it becomes too difficult to maintain all arguments
            .filter { $0.arguments.isEmpty }
            // Filter out non public tests to prevent needing @testable imports
            .filter { $0.accessLevel == .public }
    }

    /// The name of the assembly dropping the "Assembly" suffix
    var assemblyShortName: String {
        guard assemblyName.hasSuffix("Assembly") else {
            return assemblyName
        }
        return String(assemblyName.dropLast(8))
    }

    var isAbstract: Bool {
        return assemblyType == "AbstractAssembly"
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
        guard !self.isAbstract else {
            // Abstract assemblies don't need unit tests but we should still generate an empty test case
            // otherwise unit test jobs will fail if they don't find any test cases in a test target
            return .init(stringLiteral: """
            final class \(self.assemblyShortName)RegistrationTests: XCTestCase {
                func testRegistrations() {
                    // The \(self.assemblyName) is an abstract-only assembly
                    // so no registration tests are needed
                }
            }
            """)
        }
        return try UnitTestSourceFile.make(
            configuration: self,
            testAssemblerClass: assemblyName,
            isAdditionalTest: false
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
