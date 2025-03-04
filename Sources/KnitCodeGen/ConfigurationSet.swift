//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

// Multiple assemblies that are grouped together
public struct ConfigurationSet {

    public let assemblies: [Configuration]

    /// Assemblies which were also parsed but will not have full generation
    public let externalTestingAssemblies: [Configuration]

    /// Dependencies of this module
    public let moduleDependencies: [String]

    public var primaryAssembly: Configuration {
        // There must be at least 1 assembly and the first is treated as primary
        return assemblies[0]
    }

    public func writeGeneratedFiles(
        typeSafetyExtensionsOutputPath: String?,
        unitTestOutputPath: String?,
        knitModuleOutputPath: String?
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

        if let knitModuleOutputPath {
            write(
                text: try makeKnitModuleSourceFile(),
                to: knitModuleOutputPath
            )
        }
    }

    var allImports: ModuleImportSet {
        return ModuleImportSet(imports: assemblies.flatMap { $0.imports })
    }

    public var allAssemblies: [Configuration] {
        return assemblies + externalTestingAssemblies
    }
}

public extension ConfigurationSet {

    func makeTypeSafetySourceFile() throws -> String {
        var allImports = allImports
        allImports.insert(.named("Knit"))
        let header = HeaderSourceFile.make(imports: allImports.sorted, comment: Self.typeSafetyIntro)
        let body = try assemblies.map { try $0.makeTypeSafetySourceFile() }
        let sourceFiles = [header] + body
        return Self.join(sourceFiles: sourceFiles)
    }

    func makeUnitTestSourceFile() throws -> String {
        let header = HeaderSourceFile.make(imports: unitTestImports().sorted, comment: nil)
        var body = try assemblies
            .map { try $0.makeUnitTestSourceFile() }
        body.append(contentsOf: try makeAdditionalTestsSources())
        let sourceFiles = [header] + body

        return Self.join(sourceFiles: sourceFiles)
    }

    func makeKnitModuleSourceFile() throws -> String {
        var moduleImports = ModuleImportSet(imports: moduleDependencies.map { .named($0) })
        moduleImports.insert(.named("Knit"))
        let header = HeaderSourceFile.make(imports: moduleImports.sorted, comment: nil)
        let body = try KnitModuleSourceFile.make(configurations: self.assemblies, dependencies: moduleDependencies)
        let sourceFiles = [header, body]
        return Self.join(sourceFiles: sourceFiles)
    }

    // Additional assemblies will be tested using the module assembler from one of the main assemblies
    // Certain registrations will be excluded for simplicity
    func makeAdditionalTestsSources() throws -> [SourceFileSyntax] {
        return try externalTestingAssemblies.compactMap { assembly in

            if assembly.registrationsCompatibleWithCompleteTests.count == 0 {
                // If we don't have any registrations that will be tested, skip this assembly
                return nil
            }

            // Find the assembly with the same resolver type
            // If none exists don't generate any tests
            guard let matchingAssembly = assemblies.first(where: { $0.targetResolver == assembly.targetResolver }) else {
                return nil
            }

            return try UnitTestSourceFile.make(
                configuration: assembly,
                testAssemblerClass: matchingAssembly.assemblyName,
                isAdditionalTest: true
            )
        }
    }

    func unitTestImports() -> ModuleImportSet {
        var imports = ModuleImportSet(imports: allAssemblies.flatMap { $0.imports })
        imports.insert(ModuleImport.testable(name: primaryAssembly.moduleName))
        imports.insert(.named("KnitTesting"))
        imports.insert(.named("XCTest"))

        let additionalImports = externalTestingAssemblies
            .filter { $0.registrationsCompatibleWithCompleteTests.count > 0 }
            .map { ModuleImport.named($0.moduleName) }

        imports.insert(contentsOf: additionalImports)
        return imports
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

// MARK: - Validation

/// Validate that there are not duplicate registrations _within_ this ConfigurationSet
/// which represents a single module.
/// Note that this will not find duplicate registrations across modules.
extension ConfigurationSet {

    private struct Key: Hashable {
        let service: String
        let name: String?
        let arguments: [String]
    }

    public func validateNoDuplicateRegistrations() throws {
        var registrationSetPerTargetResolver = [String: Set<Key>]()

        try assemblies
            // Get all registrations across all assemblies
            .forEach { assembly in
                let targetResolver = assembly.targetResolver

                // First make sure there is a Set assigned for this assembly's TargetResolver
                if registrationSetPerTargetResolver[targetResolver] == nil {
                    registrationSetPerTargetResolver[targetResolver] = Set()
                }

                try assembly.registrations.forEach { registration in
                    let key = Key(
                        service: registration.service,
                        name: registration.name,
                        arguments: registration.arguments.map { $0.type }
                    )

                    guard let registrationSet = registrationSetPerTargetResolver[targetResolver],
                          registrationSet.contains(key) == false else {
                        throw ConfigurationSetParsingError.detectedDuplicateRegistration(
                            service: key.service,
                            name: key.name,
                            arguments: key.arguments
                        )
                    }

                    var set = registrationSetPerTargetResolver[targetResolver]!
                    set.insert(key)
                    registrationSetPerTargetResolver[targetResolver] = set
                }
            }
    }

}

enum ConfigurationSetParsingError: LocalizedError {

    case detectedDuplicateRegistration(service: String, name: String?, arguments: [String])

    var errorDescription: String? {
        switch self {
        case .detectedDuplicateRegistration(let service, let name, let arguments):
            return """
                    Detected a duplicated registration:
                    Service type: \(service)
                    Name (optional): \(name ?? "`nil`")
                    Arguments: \(arguments)
                    """
        }
    }

}
