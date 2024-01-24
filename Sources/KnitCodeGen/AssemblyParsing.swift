//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax
import SwiftParser

public func parseAssemblies(
    at paths: [String],
    defaultTargetResolver: String,
    useTargetResolver: Bool
) throws -> ConfigurationSet {
    var configs = [Configuration]()
    for path in paths {
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
            errorsToPrint: &errorsToPrint,
            defaultTargetResolver: defaultTargetResolver,
            useTargetResolver: useTargetResolver
        )
        configs.append(configuration)
        printErrors(errorsToPrint, filePath: path, syntaxTree: syntaxTree)
    }
    return ConfigurationSet(assemblies: configs)
}

func parseSyntaxTree(
    _ syntaxTree: SyntaxProtocol,
    errorsToPrint: inout [Error],
    defaultTargetResolver: String,
    useTargetResolver: Bool
) throws -> Configuration {
    let assemblyFileVisitor = AssemblyFileVisitor()
    assemblyFileVisitor.walk(syntaxTree)

    guard let name = assemblyFileVisitor.moduleName else {
        throw AssemblyParsingError.missingModuleName
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
        name: name,
        registrations: assemblyFileVisitor.registrations,
        registrationsIntoCollections: assemblyFileVisitor.registrationsIntoCollections,
        imports: assemblyFileVisitor.imports,
        targetResolver: targetResolver
    )
}

private class AssemblyFileVisitor: SyntaxVisitor, IfConfigVisitor {

    /// The imports that were found in the tree.
    private(set) var imports = [ModuleImport]()

    private(set) var moduleName: String?

    private var classDeclVisitor: ClassDeclVisitor?

    private(set) var assemblyErrors: [Error] = []
    
    /// For any imports parsed, this #if condition should be applied when it is used
    var currentIfConfigCondition: ExprSyntax?

    var registrations: [Registration] {
        return classDeclVisitor?.registrations ?? []
    }

    var registrationsIntoCollections: [RegistrationIntoCollection] {
        return classDeclVisitor?.registrationsIntoCollections ?? []
    }

    var registrationErrors: [Error] {
        return classDeclVisitor?.registrationErrors ?? []
    }

    var targetResolver: String? {
        return classDeclVisitor?.targetResolver
    }

    init() {
        super.init(viewMode: .fixedUp)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        return visitAssemblyType(node)
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        return visitAssemblyType(node)
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        imports.append(
            ModuleImport(
                decl: node.trimmed,
                ifConfigCondition: currentIfConfigCondition
            )
        )
        return .skipChildren
    }

    override func visit(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind {
        do {
            return try self.visitIfNode(node)
        } catch {
            assemblyErrors.append(error)
            return .skipChildren
        }
    }

    private func visitAssemblyType(_ node: NamedDeclSyntax) -> SyntaxVisitorContinueKind {
        guard classDeclVisitor == nil else {
            // Only the first class declaration should be visited
            return .skipChildren
        }
        var directives: KnitDirectives = .empty
        do {
             directives = try KnitDirectives.parse(leadingTrivia: node.leadingTrivia)
        } catch {
            assemblyErrors.append(error)
        }

        moduleName = node.moduleNameForAssembly
        classDeclVisitor = ClassDeclVisitor(viewMode: .fixedUp, directives: directives)
        classDeclVisitor?.walk(node)
        return .skipChildren
    }

}

private class ClassDeclVisitor: SyntaxVisitor, IfConfigVisitor {

    private let directives: KnitDirectives

    /// The registrations that were found in the tree.
    private(set) var registrations = [Registration]()

    /// The registrations into collections that were found in the tree
    private(set) var registrationsIntoCollections = [RegistrationIntoCollection]()

    private(set) var registrationErrors = [Error]()

    private(set) var targetResolver: String?

    /// For any registrations parsed, this #if condition should be applied when it is used
    var currentIfConfigCondition: ExprSyntax?

    init(viewMode: SyntaxTreeViewMode, directives: KnitDirectives) {
        self.directives = directives
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        do {
            var (registrations, registrationsIntoCollections) = try node.getRegistrations(defaultDirectives: directives)
            registrations = registrations.map { registration in
                var mutable = registration
                mutable.ifConfigCondition = currentIfConfigCondition
                return mutable
            }
            self.registrations.append(contentsOf: registrations)
            self.registrationsIntoCollections.append(contentsOf: registrationsIntoCollections)
        } catch {
            registrationErrors.append(error)
        }

        return .skipChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        // There could be computed properties that contain other function calls we don't want to parse
        return .skipChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == "TargetResolver",
           let identifier = node.initializer.value.as(IdentifierTypeSyntax.self) {
            self.targetResolver = identifier.name.text
        }

        return .skipChildren
    }

    override func visit(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind {
        do {
            return try self.visitIfNode(node)
        } catch {
            registrationErrors.append(error)
            return .skipChildren
        }
    }

}

extension NamedDeclSyntax {

    /// Returns the module name for the assembly class.
    /// If the class is not an assembly returns `nil`.
    var moduleNameForAssembly: String? {
        let className = name.text
        let assemblySuffx = "Assembly"
        guard className.hasSuffix(assemblySuffx) else {
            return nil
        }
        return String(className.dropLast(assemblySuffx.count))
    }

}

// MARK: - Errors

enum AssemblyParsingError: Error {
    case fileReadError(Error, path: String)
    case missingModuleName
}

extension AssemblyParsingError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case let .fileReadError(error, path: path):
            return """
                   Error reading file: \(error.localizedDescription)
                   File path: \(path)
                   """

        case .missingModuleName:
            return "Cannot generate unit test source file without a module name. " +
                "Is your Assembly file setup correctly?"
        }
    }

}

// Output any errors that occurred during parsing
func printErrors(_ errors: [Error], filePath: String, syntaxTree: SyntaxProtocol) {
    guard !errors.isEmpty else {
        return
    }
    let lineConverter = SourceLocationConverter(fileName: filePath, tree: syntaxTree)

    for error in errors {
        if let syntaxError = error as? SyntaxError {
            let position = syntaxError.syntax.startLocation(converter: lineConverter, afterLeadingTrivia: true)
            let line = position.line
            print("\(filePath):\(line): error: \(error.localizedDescription)")
        } else {
            print("\(filePath): error: \(error.localizedDescription)")
        }
    }
}

// MARK: - IfConfigClauseSyntax

/// Visitor that is able to wrap children inside an #if block
protocol IfConfigVisitor: AnyObject {
    /// For any children parsed, this should be #if condition should be applied when it is used
    var currentIfConfigCondition: ExprSyntax? { get set }
    func walk(_ node: some SyntaxProtocol)
}

extension IfConfigVisitor {
    func visitIfNode(_ node: IfConfigClauseSyntax) throws -> SyntaxVisitorContinueKind {
        // Allowing for #else creates a link between the registration inside the #if and those in the #else
        // This greatly increases the complexity of handling #if so raise an error when #else is used
        if node.poundKeyword.text.contains("#else") {
            throw RegistrationParsingError.invalidIfConfig(syntax: node, text: node.poundKeyword.text)
        }
        // Raise an error for nested if statements
        if self.currentIfConfigCondition != nil {
            throw RegistrationParsingError.nestedIfConfig(syntax: node)
        }
        // Set the condition and walk the children
        self.currentIfConfigCondition = node.condition
        node.children(viewMode: .sourceAccurate).forEach { syntax in
            walk(syntax)
        }
        self.currentIfConfigCondition = nil
        return .skipChildren
    }
}
