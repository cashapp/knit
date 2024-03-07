//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

// Multiple assemblies that are grouped together
public struct ConfigurationSet {

    public let assemblies: [Configuration]

    public var primaryAssembly: Configuration {
        // There must be at least 1 assembly and the first is treated as primary
        return assemblies[0]
    }

    public func writeGeneratedFiles(
        typeSafetyExtensionsOutputPath: String?,
        unitTestOutputPath: String?
    ) throws {
        if let typeSafetyExtensionsOutputPath {
            write(
                text: try makeTypeSafetySourceFile(),
                to: typeSafetyExtensionsOutputPath
            )
        }

        if let unitTestOutputPath {
            write(
                text: try makeUnitTestSourceFile(),
                to: unitTestOutputPath
            )
        }
    }

    var allImports: ModuleImportSet {
        return ModuleImportSet(imports: assemblies.flatMap { $0.imports })
    }
}

public extension ConfigurationSet {

    func makeTypeSafetySourceFile() throws -> String {
        var allImports = allImports
        allImports.insert(.named("Swinject"))
        let header = HeaderSourceFile.make(imports: allImports.sorted, comment: Self.typeSafetyIntro)
        let body = try assemblies.map { try $0.makeTypeSafetySourceFile() }
        let sourceFiles = [header] + body
        return Self.join(sourceFiles: sourceFiles)
    }

    func makeUnitTestSourceFile() throws -> String {
        var allImports = allImports
        allImports.insert(.testable(name: primaryAssembly.moduleName))
        allImports.insert(.named("XCTest"))
        let header = HeaderSourceFile.make(imports: allImports.sorted, comment: nil)
        let body = try assemblies.map { try $0.makeUnitTestSourceFile() }
        let allRegistrations = assemblies.flatMap { $0.registrations }
        let allRegistrationsIntoCollections = assemblies.flatMap { $0.registrationsIntoCollections }
        let resolverExtensions = try UnitTestSourceFile.resolverExtensions(
            registrations: allRegistrations,
            registrationsIntoCollections: allRegistrationsIntoCollections
        )
        let sourceFiles = [header] + body + [resolverExtensions]
        return Self.join(sourceFiles: sourceFiles)
    }

    private static func join(sourceFiles: [SourceFileSyntax]) -> String {
        let result = sourceFiles.map { $0.formatted().description }.joined(separator: "\n")
        return result
    }

    private static let typeSafetyIntro = """
                // The correct resolution of each of these types is enforced by a matching automated unit test
                // If a type registration is missing or broken then the automated tests will fail for that PR
                """

}

// MARK: - Private Extensions

private extension Sequence {
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var set = Set<T>()
        return filter { set.insert($0[keyPath: keyPath]).inserted }
    }
}
