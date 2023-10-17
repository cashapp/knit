//  Created by Alexander skorulis on 4/8/2023.

import Foundation
import SwiftSyntax

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
    ) {
        if let typeSafetyExtensionsOutputPath {
            write(
                text: makeTypeSafetySourceFile(),
                to: typeSafetyExtensionsOutputPath
            )
        }

        if let unitTestOutputPath {
            write(
                text: makeUnitTestSourceFile(),
                to: unitTestOutputPath
            )
        }
    }

    var allImports: [ImportDeclSyntax] {
        assemblies
            .flatMap { $0.imports }
            .uniqued(by: \.description)
    }
}

public extension ConfigurationSet {

    func makeTypeSafetySourceFile() -> String {
        var allImports = allImports
        allImports.append("import Swinject")
        let header = HeaderSourceFile.make(importDecls: sortImports(allImports), comment: Self.typeSafetyIntro)
        let body = assemblies.map { $0.makeTypeSafetySourceFile() }
        let sourceFiles = [header] + body
        return Self.join(sourceFiles: sourceFiles)
    }

    func makeUnitTestSourceFile() -> String {
        var allImports = allImports
        allImports.append("@testable import \(raw: primaryAssembly.name)")
        allImports.append("import XCTest")
        let header = HeaderSourceFile.make(importDecls: sortImports(allImports), comment: nil)
        let body = assemblies.map { $0.makeUnitTestSourceFile() }
        let allRegistrations = assemblies.flatMap { $0.registrations }
        let allRegistrationsIntoCollections = assemblies.flatMap { $0.registrationsIntoCollections }
        let resolverExtensions = UnitTestSourceFile.resolverExtensions(
            registrations: allRegistrations,
            registrationsIntoCollections: allRegistrationsIntoCollections
        )
        let sourceFiles = [header] + body + [resolverExtensions]
        return Self.join(sourceFiles: sourceFiles)
    }

    private static func join(sourceFiles: [SourceFileSyntax]) -> String {
        let result = sourceFiles.map { $0.formatted().description }.joined(separator: "\n")
        return result.replacingOccurrences(of: ", \n", with: ",\n")
    }

    private func sortImports(_ imports: [ImportDeclSyntax]) -> [ImportDeclSyntax] {
        return imports.sorted { import1, import2 in
            let i1Name = import1.description.replacingOccurrences(of: "@testable ", with: "")
            let i2Name = import2.description.replacingOccurrences(of: "@testable ", with: "")
            return i1Name < i2Name
        }
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
