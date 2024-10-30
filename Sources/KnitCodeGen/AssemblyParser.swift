//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax
import SwiftParser

public struct AssemblyParser {

    private let defaultTargetResolver: String
    private let nameExtractor: ModuleNameExtractor

    public init(
        defaultTargetResolver: String = "Resolver",
        moduleNameRegex: String? = nil
    ) throws {
        self.defaultTargetResolver = defaultTargetResolver
        self.nameExtractor = try ModuleNameExtractor(moduleNamePattern: moduleNameRegex)
    }

    public func parseAssemblies(
        at paths: [String],
        externalTestingAssemblies: [String],
        moduleDependencies: [String]
    ) throws -> ConfigurationSet {
        let configs = try paths.flatMap { path in
            return try parse(
                path: path,
                defaultTargetResolver: defaultTargetResolver
            )
        }
        let additionalConfigs = try externalTestingAssemblies.flatMap { path in
            return try parse(
                path: path,
                defaultTargetResolver: defaultTargetResolver
            )
        }

        return ConfigurationSet(
            assemblies: configs,
            externalTestingAssemblies: additionalConfigs,
            moduleDependencies: moduleDependencies
        )
    }

    private func parse(path: String, defaultTargetResolver: String) throws -> [Configuration] {
        let url = URL(fileURLWithPath: path, isDirectory: false)
        var errorsToPrint = [Error]()

        let source: String
        do {
            source = try String(contentsOf: url)
        } catch {
            throw AssemblyParsingError.fileReadError(error, path: path)
        }
        let syntaxTree = Parser.parse(source: source)
        let configurations = try parseSyntaxTree(
            syntaxTree,
            path: path,
            errorsToPrint: &errorsToPrint
        )
        printErrors(errorsToPrint, filePath: path, syntaxTree: syntaxTree)
        if errorsToPrint.count > 0 {
            throw AssemblyParsingError.parsingError
        }
        return configurations
    }

    func parseSyntaxTree(
        _ syntaxTree: SyntaxProtocol,
        path: String? = nil,
        errorsToPrint: inout [Error]
    ) throws -> [Configuration] {

        let assemblyFileVisitor = AssemblyFileVisitor()
        assemblyFileVisitor.walk(syntaxTree)

        errorsToPrint.append(contentsOf: assemblyFileVisitor.assemblyErrors)
        errorsToPrint.append(contentsOf: assemblyFileVisitor.registrationErrors)
        
        // If the file doesn't contain assemblies in a valid format, throw to let the developer know
        if assemblyFileVisitor.classDeclVisitors.isEmpty && !assemblyFileVisitor.hasIgnoredConfigurations {
            throw AssemblyParsingError.noAssembliesFound(path ?? "Missing Path")
        }


        let configurations = try assemblyFileVisitor.classDeclVisitors.compactMap { classVisitor in
            return try makeConfiguration(
                classDeclVisitor: classVisitor,
                assemblyFileVisitor: assemblyFileVisitor,
                path: path
            )
        }
        let moduleNames =  Set(configurations.map { $0.moduleName })
        if moduleNames.count > 1 {
            throw AssemblyParsingError.moduleNameMismatch
        }

        return configurations
    }

    private func makeConfiguration(
        classDeclVisitor: ClassDeclVisitor,
        assemblyFileVisitor: AssemblyFileVisitor,
        path: String?
    ) throws -> Configuration? {
        if classDeclVisitor.directives.accessLevel == .ignore {
            return nil
        }
        var extractedModuleName: String?
        if let path {
            extractedModuleName = nameExtractor.extractModuleName(path: path)
        }
        let moduleName = classDeclVisitor.directives.moduleName ?? extractedModuleName ?? classDeclVisitor.moduleName

        let targetResolver: String = classDeclVisitor.targetResolver ?? defaultTargetResolver

        guard let assemblyType = classDeclVisitor.assemblyType else {
            throw AssemblyParsingError.missingAssemblyType
        }

        let replaces: [String]
        if let classDeclReplaces = classDeclVisitor.replaces {
            // The assembly type manually declared a `static replaces`
            // so use what is defined there
            replaces = classDeclReplaces.0
        } else if classDeclVisitor.assemblyType == .fakeAssembly {
            // The assembly conforms to `FakeAssembly`, so will have a `typealias ReplacedAssembly`
            // There is a default extension that will return the `ReplacedAssembly` from `static replaces` at runtime
            guard let fakeReplacesType = classDeclVisitor.fakeReplacesType else {
                throw AssemblyParsingError.missingReplacedAssemblyTypealias
            }
            replaces = [fakeReplacesType]
        } else {
            replaces = []
        }

        return Configuration(
            assemblyName: classDeclVisitor.assemblyName,
            moduleName: moduleName,
            directives: classDeclVisitor.directives,
            assemblyType: assemblyType,
            registrations: classDeclVisitor.registrations,
            registrationsIntoCollections: classDeclVisitor.registrationsIntoCollections,
            imports: assemblyFileVisitor.imports,
            replaces: replaces,
            targetResolver: targetResolver
        )
    }
}
