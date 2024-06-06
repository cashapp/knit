//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax
import SwiftParser

public struct AssemblyParser {

    private let defaultTargetResolver: String
    private let useTargetResolver: Bool
    private let nameExtractor: ModuleNameExtractor

    public init(
        defaultTargetResolver: String = "Resolver",
        useTargetResolver: Bool = false,
        moduleNameRegex: String? = nil
    ) throws {
        self.defaultTargetResolver = defaultTargetResolver
        self.useTargetResolver = useTargetResolver
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
                defaultTargetResolver: defaultTargetResolver,
                useTargetResolver: useTargetResolver
            )
        }
        let additionalConfigs = try externalTestingAssemblies.flatMap { path in
            return try parse(
                path: path,
                defaultTargetResolver: defaultTargetResolver,
                useTargetResolver: useTargetResolver
            )
        }

        return ConfigurationSet(
            assemblies: configs,
            externalTestingAssemblies: additionalConfigs,
            moduleDependencies: moduleDependencies
        )
    }

    private func parse(path: String, defaultTargetResolver: String, useTargetResolver: Bool) throws -> [Configuration] {
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

        let targetResolver: String
        if useTargetResolver {
            targetResolver = classDeclVisitor.targetResolver ?? defaultTargetResolver
        } else {
            targetResolver = defaultTargetResolver
        }

        guard let assemblyType = classDeclVisitor.assemblyType else {
            throw AssemblyParsingError.missingAssemblyType
        }

        let fakeImplements = classDeclVisitor.fakeImplementedType.map { [$0] } ?? []

        return Configuration(
            assemblyName: classDeclVisitor.assemblyName,
            moduleName: moduleName,
            directives: classDeclVisitor.directives,
            assemblyType: assemblyType,
            registrations: classDeclVisitor.registrations,
            registrationsIntoCollections: classDeclVisitor.registrationsIntoCollections,
            imports: assemblyFileVisitor.imports,
            implements: fakeImplements + classDeclVisitor.implements,
            targetResolver: targetResolver
        )
    }
}
