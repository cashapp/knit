//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
@preconcurrency import SwiftSyntax
@preconcurrency import SwiftParser

class AssemblyFileVisitor: SyntaxVisitor, IfConfigVisitor {

    /// The imports that were found in the tree.
    private(set) var imports = [ModuleImport]()

    private(set) var classDeclVisitors: [ClassDeclVisitor] = []

    private(set) var hasIgnoredConfigurations: Bool = false

    private(set) var assemblyErrors: [Error] = []

    /// For any imports parsed, this #if condition should be applied when it is used
    var currentIfConfigCondition: IfConfigVisitorCondition?

    var registrationErrors: [Error] {
        return classDeclVisitors.flatMap { $0.registrationErrors }
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
        var directives: KnitDirectives = .empty
        do {
            directives = try KnitDirectives.parse(leadingTrivia: node.leadingTrivia)

            if directives.accessLevel == .ignore {
                // Entire assembly is marked as ignore, stop parsing
                self.hasIgnoredConfigurations = true
                return .skipChildren
            }
        } catch {
            assemblyErrors.append(error)
        }

        let names = node.namesForAssembly
        guard let assemblyName = names?.0,
              let moduleName = node.namesForAssembly?.1 else {
            return .skipChildren
        }

        let inheritedTypes = inheritance?.inheritedTypes.compactMap {
            if let identifier = $0.type.as(IdentifierTypeSyntax.self) {
                return identifier.name.text
            } else if let member = $0.type.as(MemberTypeSyntax.self) {
                return member.name.text
            } else {
                return nil
            }
        }
        let assemblyType = inheritedTypes?
            .first { $0.hasSuffix(Configuration.AssemblyType.suffix) }
            .flatMap { Configuration.AssemblyType(rawValue: $0) }

        let classDeclVisitor = ClassDeclVisitor(
            viewMode: .fixedUp,
            directives: directives,
            assemblyName: assemblyName,
            moduleName: moduleName,
            assemblyType: assemblyType
        )
        classDeclVisitor.walk(node)

        // Validate across properties on the visitor
        classDeclVisitor.performPostWalkingValidation()

        self.classDeclVisitors.append(classDeclVisitor)

        return .skipChildren
    }

}

class ClassDeclVisitor: SyntaxVisitor, IfConfigVisitor {

    let directives: KnitDirectives
    let assemblyType: Configuration.AssemblyType?
    let assemblyName: String
    let moduleName: String

    /// The registrations that were found in the tree.
    private(set) var registrations = [Registration]()

    /// A tuple of the replaced assemblies as declared by `static var replaces` on the assembly,
    /// and the syntax node where `replaces` was defined (for later potential error message).
    /// If the assembly does not manually declare `static var replaces` then this will be `nil`.
    private(set) var replaces: ([String], SyntaxProtocol)?

    /// The registrations into collections that were found in the tree
    private(set) var registrationsIntoCollections = [RegistrationIntoCollection]()

    private(set) var registrationErrors = [Error]()

    private(set) var targetResolver: String?

    private(set) var fakeReplacesType: String?

    /// For any registrations parsed, this #if condition should be applied when it is used
    var currentIfConfigCondition: IfConfigVisitorCondition?

    init(
        viewMode: SyntaxTreeViewMode,
        directives: KnitDirectives,
        assemblyName: String,
        moduleName: String,
        assemblyType: Configuration.AssemblyType?
    ) {
        self.directives = directives
        self.assemblyName = assemblyName
        self.moduleName = moduleName
        self.assemblyType = assemblyType
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if let error = currentIfConfigCondition?.error {
            registrationErrors.append(error)
            return .skipChildren
        }
        do {
            var (registrations, registrationsIntoCollections) = try node.getRegistrations(
                defaultDirectives: directives,
                abstractOnly: assemblyType == .abstractAssembly
            )
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
        guard let binding = node.bindings.first,
              node.modifiers.contains(where: {
                  $0.name.tokenKind == .keyword(.static)
              }),
              let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              name == "replaces"
        else {
            return .skipChildren
        }
        if case let .getter(codeBlock) = binding.accessorBlock?.accessors {
            self.replaces = (
                extractReplaces(syntax: codeBlock),
                node
            )
            return .skipChildren
        }
        if let arrayInit = binding.initializer?.value.as(ArrayExprSyntax.self) {
            self.replaces = (
                extractReplaces(array: arrayInit),
                node
            )
            return .skipChildren
        }
        registrationErrors.append(ReplacesParsingError.unexpectedSyntax(syntax: binding))

        // There could be computed properties that contain other function calls we don't want to parse
        return .skipChildren
    }

    private func extractReplaces(syntax: CodeBlockItemListSyntax) -> [String] {
        var replaces: [String] = []
        syntax.forEach { item in
            if let array = item.item.as(ArrayExprSyntax.self) {
                replaces.append(contentsOf: extractReplaces(array: array))
            }
        }
        return replaces
    }

    private func extractReplaces(array: ArrayExprSyntax) -> [String] {
        return array.elements.compactMap { element in
            let memberAccess = element.expression.as(MemberAccessExprSyntax.self)
            let decl = memberAccess?.base?.as(DeclReferenceExprSyntax.self)?.baseName
            if let name = decl?.text {
                return name
            }
            return nil
        }
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let identifier = node.initializer.value.as(IdentifierTypeSyntax.self) else {
            return .skipChildren
        }
        if node.name.text == "TargetResolver" {
            self.targetResolver = identifier.name.text
        } else if node.name.text == "ReplacedAssembly" {
            self.fakeReplacesType = identifier.name.text
        }

        return .skipChildren
    }

    override func visit(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind {
        return self.visitIfNode(node)
    }

    // Validation steps to be performed after all nodes have been visited
    func performPostWalkingValidation() {
        // Validate that if the assembly is a `FakeAssembly` and declares a manual `static var replaces`,
        // that the `ReplacedAssembly` is included in `replaces`
        if assemblyType == .fakeAssembly, let replaces, let fakeReplacesType {
            if !replaces.0.contains(where: { string in
                string == fakeReplacesType
            }) {
                registrationErrors.append(
                    ReplacesParsingError.missingReplacedAssembly(syntax: replaces.1)
                )
            }
        }

        // If the assembly is a `FakeAssembly` and declares a manual `static var replaces`
        // that only contains the `ReplacedAssembly` typealias, then that `static var replaces` is redundant
        // and should be removed.
        if assemblyType == .fakeAssembly, let replaces, replaces.0.count == 1, replaces.0.first == fakeReplacesType {
            registrationErrors.append(
                ReplacesParsingError.redundantDeclaration(syntax: replaces.1)
            )
        }
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
    case missingAssemblyType
    case missingTargetResolver
    case parsingError
    case noAssembliesFound(String)
    case moduleNameMismatch(names: [String])
    case missingReplacedAssemblyTypealias
}

extension AssemblyParsingError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case let .fileReadError(error, path: path):
            return """
                   Error reading file: \(error.localizedDescription)
                   File path: \(path)
                   """
        case .parsingError:
            return "There were one or more errors parsing the assembly file"
        case .missingAssemblyType:
            return "Assembly files must inherit from an *Assembly type"
        case .missingTargetResolver:
            return "ModuleAssembly is required to declare a TargetResolver"
        case let .noAssembliesFound(path):
            return "The given file path did not contain any valid assemblies: \(path)"
        case let .moduleNameMismatch(names):
            return "Assemblies in a single file have different modules: \(names.joined(separator: ", "))."
        case .missingReplacedAssemblyTypealias:
            return "The FakeAssembly is missing a required `typealias ReplacedAssembly`"
        }
    }
}

enum ReplacesParsingError: LocalizedError, SyntaxError {
    case unexpectedSyntax(syntax: SyntaxProtocol)
    case missingReplacedAssembly(syntax: SyntaxProtocol)
    case redundantDeclaration(syntax: SyntaxProtocol)

    var errorDescription: String? {
        switch self {
        case .unexpectedSyntax:
            return "Unexpected replaces syntax"
        case .missingReplacedAssembly:
            return "Manually declared `replaces` array is missing required `ReplacedAssembly` type"
        case .redundantDeclaration:
            return "Manually declared `replaces` array is unnecessary, just use the `ReplacedAssembly` typealias"
        }
    }

    var syntax: SyntaxProtocol {
        switch self {
        case let .unexpectedSyntax(syntax),
            let .missingReplacedAssembly(syntax: syntax),
            let .redundantDeclaration(syntax: syntax):
            return syntax
        }
    }

    var positionAboveNode: Bool {
        return false
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
            FileHandle.standardError.write(Data(
                syntaxError.standardErrorDescription(lineConverter: lineConverter).utf8
            ))
        } else {
            FileHandle.standardError.write(Data(
                "\(filePath): error: \(error.localizedDescription)\n".utf8
            ))
        }
    }
}

extension SyntaxError {

    func standardErrorDescription(lineConverter: SourceLocationConverter) -> String {
        let position = self.syntax.startLocation(
            converter: lineConverter,
            afterLeadingTrivia: true
        )
        let filePath = position.file
        let line = positionAboveNode ? position.line - 1 : position.line
        let column = position.column

        return "\(filePath):\(line):\(column): error: \(self.localizedDescription)\n"
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
