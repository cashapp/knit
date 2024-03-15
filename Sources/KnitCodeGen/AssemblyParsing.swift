//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax
import SwiftParser
 
class AssemblyFileVisitor: SyntaxVisitor, IfConfigVisitor {

    /// The imports that were found in the tree.
    private(set) var imports = [ModuleImport]()

    private(set) var assemblyName: String?

    private(set) var moduleName: String?

    private(set) var assemblyType: String?

    private(set) var directives: KnitDirectives = .empty

    private var classDeclVisitor: ClassDeclVisitor?

    private(set) var assemblyErrors: [Error] = []
    
    /// For any imports parsed, this #if condition should be applied when it is used
    var currentIfConfigCondition: IfConfigVisitorCondition?

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
        return visitAssemblyType(node, node.inheritanceClause)
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        return visitAssemblyType(node, node.inheritanceClause)
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        if let error = currentIfConfigCondition?.error {
            assemblyErrors.append(error)
            return .skipChildren
        }
        imports.append(
            ModuleImport(
                decl: node.trimmed,
                ifConfigCondition: currentIfConfigCondition?.condition
            )
        )
        return .skipChildren
    }

    override func visit(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind {
        return self.visitIfNode(node)
    }

    private func visitAssemblyType(_ node: NamedDeclSyntax, _ inheritance: InheritanceClauseSyntax?) -> SyntaxVisitorContinueKind {
        guard classDeclVisitor == nil else {
            // Only the first class declaration should be visited
            return .skipChildren
        }
        do {
            directives = try KnitDirectives.parse(leadingTrivia: node.leadingTrivia)

            if directives.accessLevel == .ignore {
                // Entire assembly is marked as ignore, stop parsing
                return .skipChildren
            }

        } catch {
            assemblyErrors.append(error)
        }

        let names = node.namesForAssembly
        assemblyName = names?.0
        moduleName = node.namesForAssembly?.1

        let inheritedTypes = inheritance?.inheritedTypes.map {
            $0.type.description.trimmingCharacters(in: .whitespaces)
        }
        self.assemblyType = inheritedTypes?.first(where: { $0.hasSuffix("Assembly")})
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
    var currentIfConfigCondition: IfConfigVisitorCondition?

    init(viewMode: SyntaxTreeViewMode, directives: KnitDirectives) {
        self.directives = directives
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if let error = currentIfConfigCondition?.error {
            registrationErrors.append(error)
            return .skipChildren
        }
        do {
            var (registrations, registrationsIntoCollections) = try node.getRegistrations(defaultDirectives: directives)
            registrations = registrations.map { registration in
                var mutable = registration
                mutable.ifConfigCondition = currentIfConfigCondition?.condition
                return mutable
            }
            let nonIgnoredRegistrations = registrations.filter { $0.accessLevel != .ignore }
            self.registrations.append(contentsOf: nonIgnoredRegistrations)
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
        return self.visitIfNode(node)
    }

}

extension NamedDeclSyntax {

    /// Returns the module name and assembly name for the assembly class.
    /// If the class is not an assembly returns `nil`.
    var namesForAssembly: (String, String)? {
        let className = name.text
        let assemblySuffx = "Assembly"
        guard className.hasSuffix(assemblySuffx) else {
            return nil
        }
        let moduleName = String(className.dropLast(assemblySuffx.count))
        return (className, moduleName)
    }

}

// MARK: - Errors

enum AssemblyParsingError: Error {
    case fileReadError(Error, path: String)
    case missingAssemblyName
    case missingModuleName
    case missingAssemblyType
    case parsingError
}

extension AssemblyParsingError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case let .fileReadError(error, path: path):
            return """
                   Error reading file: \(error.localizedDescription)
                   File path: \(path)
                   """

        case .missingAssemblyName:
            return "Cannot generate unit test source file without an assembly name. " +
                "Is your Assembly file setup correctly?"
        case .missingModuleName:
            return "Cannot generate unit test source file without a module name. " +
                "Is your Assembly file setup correctly?"
        case .parsingError:
            return "There were one or more errors parsing the assembly file"
        case .missingAssemblyType:
            return "Assembly files must inherit from an *Assembly type"
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
    var currentIfConfigCondition: IfConfigVisitorCondition? { get set }
    func walk(_ node: some SyntaxProtocol)
}

/// #if statements will either be accepted or stored as an error in case they are used later
enum IfConfigVisitorCondition {
    case syntax(ExprSyntax)
    case invalid(RegistrationParsingError)

    var condition: ExprSyntax? {
        switch self {
        case .syntax(let exprSyntax): return exprSyntax
        case .invalid:
            return nil
        }
    }

    var error: RegistrationParsingError? {
        switch self {
        case .syntax:
            return nil
        case .invalid(let registrationParsingError):
            return registrationParsingError
        }
    }
}

extension IfConfigVisitor {
    func visitIfNode(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind {
        // Allowing for #else creates a link between the registration inside the #if and those in the #else
        // This greatly increases the complexity of handling #if so raise an error when #else is used
        if node.poundKeyword.tokenKind == .poundElse {
            let error = RegistrationParsingError.invalidIfConfig(syntax: node, text: node.poundKeyword.text)
            self.currentIfConfigCondition = .invalid(error)
        } else if self.currentIfConfigCondition != nil {
            // Raise an error for nested #if statements
            let error = RegistrationParsingError.nestedIfConfig(syntax: node)
            self.currentIfConfigCondition = .invalid(error)
        } else if let condition = node.condition {
            // Set the if condition
            self.currentIfConfigCondition = .syntax(condition)
        }

        // Walk even if errors are found, they may not be relevant
        node.children(viewMode: .sourceAccurate).forEach { syntax in
            walk(syntax)
        }
        self.currentIfConfigCondition = nil
        return .skipChildren
    }
}
