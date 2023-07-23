import Foundation
import SwiftSyntax
import SwiftSyntaxParser

public func parseAssembly(at path: String) throws -> Configuration {
    let url = URL(fileURLWithPath: path, isDirectory: false)

    let syntaxTree: SourceFileSyntax
    do {
        syntaxTree = try SwiftSyntaxParser.SyntaxParser.parse(url)
    } catch {
        throw AssemblyParsingError.syntaxParsingError(error, path: path)
    }

    var errorsToPrint = [Error]()

    let configuration = try parseSyntaxTree(syntaxTree, errorsToPrint: &errorsToPrint)

    printErrors(errorsToPrint, filePath: path, syntaxTree: syntaxTree)

    return configuration
}

func parseSyntaxTree(
    _ syntaxTree: SyntaxProtocol,
    errorsToPrint: inout [Error]
) throws -> Configuration {
    let assemblyFileVisitor = AssemblyFileVisitor()
    assemblyFileVisitor.walk(syntaxTree)

    guard let name = assemblyFileVisitor.moduleName else {
        throw AssemblyParsingError.missingModuleName
    }

    errorsToPrint.append(contentsOf: assemblyFileVisitor.registrationErrors)

    return Configuration(
        name: name,
        registrations: assemblyFileVisitor.registrations,
        registrationsIntoCollections: assemblyFileVisitor.registrationsIntoCollections,
        imports: assemblyFileVisitor.imports
    )
}

private class AssemblyFileVisitor: SyntaxVisitor {

    /// The imports that were found in the tree.
    private(set) var imports = [ImportDeclSyntax]()

    private(set) var moduleName: String?

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
        let directives = KnitDirectives.parse(leadingTrivia: node.leadingTrivia)
        moduleName = node.moduleNameForAssembly
        classDeclVisitor = ClassDeclVisitor(viewMode: .fixedUp, directives: directives)
        classDeclVisitor?.walk(node)
        return .skipChildren
    }

}

private class ClassDeclVisitor: SyntaxVisitor {

    private let directives: KnitDirectives

    /// The registrations that were found in the tree.
    private(set) var registrations = [Registration]()

    /// The registrations into collections that were found in the tree
    private(set) var registrationsIntoCollections = [RegistrationIntoCollection]()

    private(set) var registrationErrors = [Error]()

    init(viewMode: SyntaxTreeViewMode, directives: KnitDirectives) {
        self.directives = directives
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        do {
            let (registrations, registrationsIntoCollections) = try node.getRegistrations(defaultDirectives: directives)
            self.registrations.append(contentsOf: registrations)
            self.registrationsIntoCollections.append(contentsOf: registrationsIntoCollections)
        } catch {
            registrationErrors.append(error)
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

enum AssemblyParsingError: Error {
    case syntaxParsingError(Error, path: String)
    case missingModuleName
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
