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
        additionalPaths: [String]
    ) throws -> ConfigurationSet {
        let configs = try paths.compactMap { path in
            return try parse(
                path: path,
                defaultTargetResolver: defaultTargetResolver,
                useTargetResolver: useTargetResolver
            )
        }
        let additionalConfigs = try additionalPaths.compactMap { path in
            return try parse(
                path: path,
                defaultTargetResolver: defaultTargetResolver,
                useTargetResolver: useTargetResolver
            )
        }

        return ConfigurationSet(assemblies: configs, additionalAssemblies: additionalConfigs)
    }

    private func parse(path: String, defaultTargetResolver: String, useTargetResolver: Bool) throws -> Configuration? {
        let url = URL(fileURLWithPath: path, isDirectory: false)
        var errorsToPrint = [Error]()

        let source: String
        do {
            source = try String(contentsOf: url)
        } catch {
            throw AssemblyParsingError.fileReadError(error, path: path)
        }
        let syntaxTree = Parser.parse(source: source)
        let configuration = try parseSyntaxTree(
            syntaxTree,
            path: path,
            errorsToPrint: &errorsToPrint
        )
        printErrors(errorsToPrint, filePath: path, syntaxTree: syntaxTree)
        if errorsToPrint.count > 0 {
            throw AssemblyParsingError.parsingError
        }
        return configuration
    }

    func parseSyntaxTree(
        _ syntaxTree: SyntaxProtocol,
        path: String? = nil,
        errorsToPrint: inout [Error]
    ) throws -> Configuration? {
        var extractedModuleName: String?
        if let path {
            extractedModuleName = nameExtractor.extractModuleName(path: path)
        }

        let assemblyFileVisitor = AssemblyFileVisitor()
        assemblyFileVisitor.walk(syntaxTree)

        if assemblyFileVisitor.directives.accessLevel == .ignore { return nil }

        guard let assemblyName = assemblyFileVisitor.assemblyName else {
            throw AssemblyParsingError.missingAssemblyName
        }
        let moduleName = assemblyFileVisitor.directives.moduleName ?? extractedModuleName ?? assemblyFileVisitor.moduleName
        guard let moduleName else {
            throw AssemblyParsingError.missingModuleName
        }

        guard let assemblyType = assemblyFileVisitor.assemblyType else {
            throw AssemblyParsingError.missingAssemblyType
        }

        errorsToPrint.append(contentsOf: assemblyFileVisitor.assemblyErrors)
        errorsToPrint.append(contentsOf: assemblyFileVisitor.registrationErrors)

        let targetResolver: String
        if useTargetResolver {
            targetResolver = assemblyFileVisitor.targetResolver ?? defaultTargetResolver
        } else {
            targetResolver = defaultTargetResolver
        }

        return Configuration(
            assemblyName: assemblyName,
            moduleName: moduleName,
            directives: assemblyFileVisitor.directives,
            assemblyType: assemblyType,
            registrations: assemblyFileVisitor.registrations,
            registrationsIntoCollections: assemblyFileVisitor.registrationsIntoCollections,
            imports: assemblyFileVisitor.imports,
            targetResolver: targetResolver
        )
    }
}
