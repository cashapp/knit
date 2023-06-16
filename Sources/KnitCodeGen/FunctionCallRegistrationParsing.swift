//
// Copyright © Square, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax

extension FunctionCallExprSyntax {

    /// Retrieve any registrations if they exist in the function call expression.
    /// Function call expressions can contain chained function calls, and this method will parse the chain.
    func getRegistrations() throws -> [Registration] {
        // Collect all chained method calls
        var calledMethods = [(calledExpr: MemberAccessExprSyntax, arguments: TupleExprElementListSyntax, closure: ClosureExprSyntax?)]()

        // Returns the base identifier token that was called
        func recurseCalledExpressions(_ funcCall: FunctionCallExprSyntax) -> TokenSyntax? {

            guard let calledExpr = funcCall.calledExpression.as(MemberAccessExprSyntax.self) else {
                return nil
            }

            // Append the method call
            calledMethods.append((calledExpr: calledExpr, arguments: funcCall.argumentList, funcCall.trailingClosure))
            if let identifierToken = calledExpr.base?.as(IdentifierExprSyntax.self)?.identifier {
                return identifierToken
            } else {
                let innerFunctionCall = calledExpr.base!.as(FunctionCallExprSyntax.self)!
                return recurseCalledExpressions(innerFunctionCall)
            }
        }

        // Kick off recursion with the current function call
        guard let baseIdentfier = recurseCalledExpressions(self) else {
            return []
        }

        // The final base identifier must be the "container" local argument
        guard baseIdentfier.text == "container" else {
            return []
        }

        let registerMethods = calledMethods.filter { calledExpr, _, _ in
            let name = calledExpr.name.text
            return name == "register" || name == "autoregister" || name == "registerAbstract"
        }

        guard registerMethods.count <= 1 else {
            fatalError("Chained registration calls are not supported")
        }

        guard let primaryRegisterMethod = registerMethods.first else {
            return []
        }

        // Arguments from the primary registration apply to all .implements() calls
        let registrationArguments = try getArguments(
            arguments: primaryRegisterMethod.arguments,
            trailingClosure: primaryRegisterMethod.closure
        )

        // The primary registration (not `.implements()`)
        guard let primaryRegistration = makeRegistrationFor(
            arguments: primaryRegisterMethod.arguments,
            registrationArguments: registrationArguments,
            leadingTrivia: self.leadingTrivia,
            isForwarded: false
        ) else {
            return []
        }

        let implementsCalledMethods = calledMethods.filter { calledExpr, _, _ in
            calledExpr.name.text == "implements"
        }

        var forwardedRegistrations = [Registration]()

        for implementsCalledMethod in implementsCalledMethods {
            // For `.implements()` the leading trivia is attached to the Dot syntax node
            let leadingTrivia = implementsCalledMethod.calledExpr.dot.leadingTrivia

            if let forwardedRegistration = makeRegistrationFor(
                arguments: implementsCalledMethod.arguments,
                registrationArguments: registrationArguments,
                leadingTrivia: leadingTrivia,
                isForwarded: true
            ) {
                forwardedRegistrations.append(forwardedRegistration)
            }
        }

        // The called methods process from the outside in, which is reverse order of how they read
        forwardedRegistrations.reverse()

        return [primaryRegistration] + forwardedRegistrations
    }

}

private func makeRegistrationFor(
    arguments: TupleExprElementListSyntax,
    registrationArguments: [String],
    leadingTrivia: Trivia?,
    isForwarded: Bool
) -> Registration? {
    guard let firstParam = arguments.first?.as(TupleExprElementSyntax.self)?
        .expression.as(MemberAccessExprSyntax.self) else { return nil }
    guard firstParam.name.text == "self" else { return nil }

    let registrationText = firstParam.base!.withoutTrivia().description
    let accessLevel: AccessLevel
    if let leadingTrivia, leadingTrivia.description.contains("@knit public") {
        accessLevel = .public
    } else if let leadingTrivia, leadingTrivia.description.contains("@knit hidden") {
        accessLevel = .hidden
    } else {
        accessLevel = .internal
    }
    let name = getName(arguments: arguments)

    return Registration(
        service: registrationText,
        name: name,
        accessLevel: accessLevel,
        arguments: registrationArguments,
        isForwarded: isForwarded
    )
}

private func getName(arguments: TupleExprElementListSyntax) -> String? {
    let nameParam = arguments.first(where: {$0.label?.text == "name"})
    guard let name = nameParam?.expression.as(StringLiteralExprSyntax.self)?.description else {
        return nil
    }
    guard name.hasPrefix("\"") && name.hasSuffix("\"") else {
        fatalError("Service name must be a static string. Found: \(name)")
    }
    return String(name.dropFirst().dropLast())
}

private func getArguments(
    arguments: TupleExprElementListSyntax,
    trailingClosure: ClosureExprSyntax?
) throws -> [String] {
    // Check for a single argument param when using autoregister
    if let argumentParam = arguments.first(where: {$0.label?.text == "argument"}),
       let argumentType = argumentParam.expression.as(MemberAccessExprSyntax.self)?.base?.as(IdentifierExprSyntax.self)
    {
        return [argumentType.identifier.text]
    }

    // Autoregister can provide multiple arguments.
    // Everything between the `arguments` and `initializer` params is an argument
    if let argumentsParamIndex = arguments.firstIndex(where: {$0.label?.text == "arguments"}),
       let initIndex = arguments.firstIndex(where: {$0.label?.text == "initializer"}) {
        return arguments[argumentsParamIndex..<initIndex].compactMap { element in
            guard let type = element.expression.as(MemberAccessExprSyntax.self)?.base?.as(IdentifierExprSyntax.self) else {
                return nil
            }
            return type.identifier.text
        }
    }

    // This type of closure params cannot include types, so force using `ParameterClauseSyntax`
    if let paramList = trailingClosure?.signature?.input?.as(ClosureParamListSyntax.self), paramList.count >= 2 {
        throw RegistrationParsingError.unwrappedClosureParams
    }

    // Register methods take a closure with resolver and arguments. Argument types must be provided
    if let closureParameters = trailingClosure?.signature?.input?.as(ParameterClauseSyntax.self) {
        let params = closureParameters.parameterList
        // The first param is the resolver, everything after that is an argument
        return try params[params.index(after: params.startIndex)..<params.endIndex].compactMap { element in
            guard let type = element.type?.as(SimpleTypeIdentifierSyntax.self)?.name.text else {
                throw RegistrationParsingError.missingArgumentType(name: element.firstName?.text ?? "_")
            }
            return type
        }
    }

    return []
}

enum RegistrationParsingError: LocalizedError {

    case missingArgumentType(name: String)
    case unwrappedClosureParams

    var errorDescription: String? {
        switch self {
        case let .missingArgumentType(name):
            return "Registration for \(name) is missing a type. Type safe resolver has not been generated"
        case .unwrappedClosureParams:
            return "Registrations must wrap argument closures and add types: e.g. { (resolver: Resolver, arg: MyArg) in"
        }
    }

}
