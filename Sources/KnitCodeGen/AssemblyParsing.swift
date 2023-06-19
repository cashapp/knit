import Foundation
import SwiftSyntax
import SwiftSyntaxParser

/// Currently the returned Configuration includes `registrations` and `imports`.
public func parseAssembly(at path: String) throws -> Configuration {
    let url = URL(fileURLWithPath: path, isDirectory: false)

    let syntaxTree: SourceFileSyntax
    do {
        syntaxTree = try SwiftSyntaxParser.SyntaxParser.parse(url)
    } catch {
        throw AssemblyParsingError.syntaxParsingError(error, path: path)
    }

    return try parseSyntaxTree(syntaxTree, filePath: path)
}

func parseSyntaxTree(_ syntaxTree: SyntaxProtocol, filePath: String? = nil) throws -> Configuration {
    let assemblyFileVisitor = AssemblyFileVisitor()
    assemblyFileVisitor.walk(syntaxTree)

    guard let name = assemblyFileVisitor.moduleName else {
        throw AssemblyParsingError.missingModuleName
    }

    return Configuration(
        filePath: filePath,
        syntaxTree: syntaxTree,
        name: name,
        registrations: assemblyFileVisitor.registrations,
        errors: assemblyFileVisitor.registrationErrors,
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
    private(set) var registrationErrors = [Error]()

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        do {
            registrations.append(contentsOf: try node.getRegistrations())
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
