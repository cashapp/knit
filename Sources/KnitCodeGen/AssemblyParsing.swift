import Foundation
import SwiftSyntax
import SwiftSyntaxParser

public func parseAssembly(
    at path: String,
    defaultResolverName: String?
) throws -> Configuration {
    let url = URL(fileURLWithPath: path, isDirectory: false)

    let syntaxTree: SourceFileSyntax
    do {
        syntaxTree = try SwiftSyntaxParser.SyntaxParser.parse(url)
    } catch {
        throw AssemblyParsingError.syntaxParsingError(error, path: path)
    }

    var errorsToPrint = [Error]()

    let configuration = try parseSyntaxTree(
        syntaxTree,
        defaultResolverName: defaultResolverName,
        errorsToPrint: &errorsToPrint
    )

    printErrors(errorsToPrint, filePath: path, syntaxTree: syntaxTree)

    return configuration
}

func parseSyntaxTree(
    _ syntaxTree: SyntaxProtocol,
    defaultResolverName: String?,
    errorsToPrint: inout [Error]
) throws -> Configuration {
    let assemblyFileVisitor = AssemblyFileVisitor()
    assemblyFileVisitor.walk(syntaxTree)

    guard let name = assemblyFileVisitor.moduleName else {
        throw AssemblyParsingError.missingModuleName
    }

    guard let resolverName = assemblyFileVisitor.resolverName ?? defaultResolverName else {
        throw AssemblyParsingError.missingTargetResolver
    }

    errorsToPrint.append(contentsOf: assemblyFileVisitor.registrationErrors)

    return Configuration(
        name: name,
        registrations: assemblyFileVisitor.registrations,
        registrationsIntoCollections: assemblyFileVisitor.registrationsIntoCollections,
        imports: assemblyFileVisitor.imports,
        resolverName: resolverName
    )
}

private class AssemblyFileVisitor: SyntaxVisitor {

    /// The imports that were found in the tree.
    private(set) var imports = [ImportDeclSyntax]()

    private(set) var moduleName: String?

    var resolverName: String? {
        classDeclVisitor?.resolverName
    }

    private var classDeclVisitor: ClassDeclVisitor?

    var registrations: [Registration] {
        return classDeclVisitor?.registrations ?? []
    }

    var registrationsIntoCollections: [RegistrationIntoCollection] {
        return classDeclVisitor?.registrationsIntoCollections ?? []
    }

    var registrationErrors: [Error] {
        return classDeclVisitor?.registrationErrors ?? []
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
        imports.append(node.withoutTrivia())
        return .skipChildren
    }

    private func visitAssemblyType(_ node: IdentifiedDeclSyntax) -> SyntaxVisitorContinueKind {
        guard classDeclVisitor == nil else {
            // Only the first class declaration should be visited
            return .skipChildren
        }
        moduleName = node.moduleNameForAssembly
        classDeclVisitor = ClassDeclVisitor(viewMode: .fixedUp)
        classDeclVisitor?.walk(node)
        return .skipChildren
    }

}

private class ClassDeclVisitor: SyntaxVisitor {

    /// The registrations that were found in the tree.
    private(set) var registrations = [Registration]()

    /// The registrations into collections that were found in the tree
    private(set) var registrationsIntoCollections = [RegistrationIntoCollection]()

    private(set) var registrationErrors = [Error]()

    private(set) var resolverName: String?

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        do {
            let (registrations, registrationsIntoCollections) = try node.getRegistrations()
            self.registrations.append(contentsOf: registrations)
            self.registrationsIntoCollections.append(contentsOf: registrationsIntoCollections)
        } catch {
            registrationErrors.append(error)
        }

        return .skipChildren
    }

    override func visit(_ node: TypealiasDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.identifier.text == "Resolver" {
            guard let simpleType = node.initializer.value.as(SimpleTypeIdentifierSyntax.self) else {
                registrationErrors.append(
                    AssemblyParsingSyntaxError.unsupportedResolverTypealias(syntax: node.initializer.value)
                )
                return .skipChildren
            }

            resolverName = simpleType.name.text
        }

        return .skipChildren
    }

}

extension IdentifiedDeclSyntax {

    /// Returns the module name for the assembly class.
    /// If the class is not an assembly returns `nil`.
    var moduleNameForAssembly: String? {
        let className = identifier.text
        let assemblySuffx = "Assembly"
        guard className.hasSuffix(assemblySuffx) else {
            return nil
        }
        return String(className.dropLast(assemblySuffx.count))
    }

}

// MARK: - Errors

// Unrecoverable errors, assembly parsing can not continue.
enum AssemblyParsingError: Error {
    case syntaxParsingError(Error, path: String)
    case missingModuleName
    case missingTargetResolver
}

extension AssemblyParsingError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case let .syntaxParsingError(error, path: path):
            return """
                   Error parsing assembly file: \(error)
                   File path: \(path)
                   """

        case .missingModuleName:
            return "Cannot generate unit test source file without a module name. " +
                "Is your Assembly file setup correctly?"

        case .missingTargetResolver:
            return "Cannot generate type safety file without a target Resolver."
        }
    }

}

// Errors that should be shown in the IDE, parsing does continue.
enum AssemblyParsingSyntaxError: Error {
    case unsupportedResolverTypealias(syntax: SyntaxProtocol)
}

extension AssemblyParsingSyntaxError: SyntaxError {

    var syntax: SyntaxProtocol {
        switch self {
        case let .unsupportedResolverTypealias(syntax: syntax):
            return syntax
        }
    }

}

extension AssemblyParsingSyntaxError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .unsupportedResolverTypealias:
            return "This type alias initializer is not supported"
        }
    }
    
}

// Output any errors that occurred during parsing
func printErrors(_ errors: [Error], filePath: String, syntaxTree: SyntaxProtocol) {
    guard !errors.isEmpty else {
        return
    }
    let lineConverter = SourceLocationConverter(file: filePath, tree: syntaxTree)

    for error in errors {
        if let syntaxError = error as? SyntaxError {
            let position = syntaxError.syntax.startLocation(converter: lineConverter, afterLeadingTrivia: true)
            let line = position.line ?? 1
            print("\(filePath):\(line): error: \(error.localizedDescription)")
        } else {
            print("\(filePath): error: \(error.localizedDescription)")
        }
    }
}
