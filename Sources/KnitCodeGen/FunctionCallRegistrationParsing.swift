//
// Copyright © Square, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax

struct CalledMethod {

    // The member access for each called expression, e.g. `object.methodName(arg1: String)`.
    let calledExpression: MemberAccessExprSyntax

    // The arguments passed to the method, e.g. `arg1: String` from the example above.
    let arguments: TupleExprElementListSyntax

    // A trailing closure after the called method (which is the last argument for that method call).
    let trailingClosure: ClosureExprSyntax?
}

extension FunctionCallExprSyntax {

    /// Retrieve any registrations if they exist in the function call expression.
    /// Function call expressions can contain chained function calls, and this method will parse the chain.
    func getRegistrations() throws -> (registrations: [Registration], registrationsIntoCollections: [RegistrationIntoCollection]) {

        let (calledMethods, baseIdentifier) = recurseAllCalledMethods(startingWith: self)

        // The final base identifier must be the "container" local argument
        guard let baseIdentifier, baseIdentifier.text == "container" else {
            return ([], [])
        }

        let registrationIntoCollection = calledMethods
            .first { method in
                let name = method.calledExpression.name.text
                return name == "registerIntoCollection" || name == "autoregisterIntoCollection"
            }
            .flatMap { method in
                makeRegistrationIntoCollection(arguments: method.arguments)
            }

        // If this is a registration into a collection, there's nothing left to parse.
        if let registrationIntoCollection {
            return ([], [registrationIntoCollection])
        }

        let registerMethods = calledMethods.filter { method in
            let name = method.calledExpression.name.text
            return name == "register" || name == "autoregister" || name == "registerAbstract"
        }

        guard registerMethods.count <= 1 else {
            throw RegistrationParsingError.chainedRegistrations(syntax: registerMethods[0].calledExpression)
        }

        guard let primaryRegisterMethod = registerMethods.first else {
            return ([], [])
        }

        // Arguments from the primary registration apply to all .implements() calls
        let registrationArguments = try getArguments(
            arguments: primaryRegisterMethod.arguments,
            trailingClosure: primaryRegisterMethod.trailingClosure
        )

        // The primary registration (not `.implements()`)
        guard let primaryRegistration = try makeRegistrationFor(
            arguments: primaryRegisterMethod.arguments,
            registrationArguments: registrationArguments,
            leadingTrivia: self.leadingTrivia,
            isForwarded: false
        ) else {
            return ([], [])
        }

        let implementsCalledMethods = calledMethods.filter { method in
            method.calledExpression.name.text == "implements"
        }

        var forwardedRegistrations = [Registration]()

        for implementsCalledMethod in implementsCalledMethods {
            // For `.implements()` the leading trivia is attached to the Dot syntax node
            let leadingTrivia = implementsCalledMethod.calledExpression.dot.leadingTrivia

            if let forwardedRegistration = try makeRegistrationFor(
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

        return ([primaryRegistration] + forwardedRegistrations, [])
    }

}

func recurseAllCalledMethods(
    startingWith startFunctionCall: FunctionCallExprSyntax
) -> (calledMethods: [CalledMethod], baseToken: TokenSyntax?) {
    // Collect all chained method calls
    var calledMethods = [CalledMethod]()

    // Returns the base identifier token that was called
    func recurseCalledExpressions(_ funcCall: FunctionCallExprSyntax) -> TokenSyntax? {

        guard let calledExpr = funcCall.calledExpression.as(MemberAccessExprSyntax.self) else {
            return nil
        }

        // Append each method call as we recurse
        calledMethods.append(CalledMethod(
            calledExpression: calledExpr,
            arguments: funcCall.argumentList,
            trailingClosure: funcCall.trailingClosure
        ))
        if let identifierToken = calledExpr.base?.as(IdentifierExprSyntax.self)?.identifier {
            return identifierToken
        } else {
            let innerFunctionCall = calledExpr.base!.as(FunctionCallExprSyntax.self)!
            return recurseCalledExpressions(innerFunctionCall)
        }
    }

    // Kick off recursion with the current function call expression
    let baseIdentifier = recurseCalledExpressions(startFunctionCall)

    return (calledMethods, baseIdentifier)
}

private func makeRegistrationFor(
    arguments: TupleExprElementListSyntax,
    registrationArguments: [Registration.Argument],
    leadingTrivia: Trivia?,
    isForwarded: Bool
) throws -> Registration? {
    guard let firstParam = arguments.first?.as(TupleExprElementSyntax.self)?
        .expression.as(MemberAccessExprSyntax.self) else { return nil }
    guard firstParam.name.text == "self" else { return nil }

    let registrationText = firstParam.base!.withoutTrivia().description
    let name = try getName(arguments: arguments)
    let directives = KnitDirectives.parse(leadingTrivia: leadingTrivia)

    return Registration(
        service: registrationText,
        name: name,
        accessLevel: directives.accessLevel ?? .default,
        arguments: registrationArguments,
        isForwarded: isForwarded,
        getterConfig: directives.getterConfig ?? .default
    )
}

private func makeRegistrationIntoCollection(
    arguments: TupleExprElementListSyntax
) -> RegistrationIntoCollection? {
    guard let firstParam = arguments.first?.as(TupleExprElementSyntax.self)?
        .expression.as(MemberAccessExprSyntax.self) else { return nil }
    guard firstParam.name.text == "self" else { return nil }

    let registrationText = firstParam.base!.withoutTrivia().description
    return RegistrationIntoCollection(service: registrationText)
}

private func getName(arguments: TupleExprElementListSyntax) throws -> String? {
    guard let nameParam = arguments.first(where: {$0.label?.text == "name"}) else {
        return nil
    }
    guard let name = nameParam.expression.as(StringLiteralExprSyntax.self)?.description else {
        throw RegistrationParsingError.nonStaticString(syntax: arguments, name: nameParam.description)
    }
    return String(name.dropFirst().dropLast())
}

private func getArguments(
    arguments: TupleExprElementListSyntax,
    trailingClosure: ClosureExprSyntax?
) throws -> [Registration.Argument] {
    // `autoregister` parsing

    // Check for a single argument param when using autoregister
    if let argumentParam = arguments.first(where: {$0.label?.text == "argument"}),
       let argumentType = getArgumentType(arg: argumentParam)
    {
        return [.init(type: argumentType)]
    }

    // Autoregister can provide multiple arguments.
    // Everything between the `arguments` and `initializer` params is an argument
    if let argumentsParamIndex = arguments.firstIndex(where: {$0.label?.text == "arguments"}),
       let initIndex = arguments.firstIndex(where: {$0.label?.text == "initializer"}) {
        return arguments[argumentsParamIndex..<initIndex].compactMap { element in
            guard let type = getArgumentType(arg: element) else {
                return nil
            }
            return .init(type: type)
        }
    }

    // `register` parsing

    // The factory closure if it exists, either as a named parameter or a trailing closure
    let factoryClosure: ClosureExprSyntax?

    // Normalize factory closure between argument and trailing closure
    if let factoryParam = arguments.first(where: { $0.label?.text == "factory" }) {
        if let closure = factoryParam.expression.as(ClosureExprSyntax.self) {
            factoryClosure = closure
        } else {
            // It is possible that a helper function is providing the closure and that is acceptable,
            // but we will not be able to detect and parse arguments
            factoryClosure = nil
        }
    } else if let trailingClosure {
        factoryClosure = trailingClosure
    } else {
        factoryClosure = nil
    }

    // This type of closure param list syntax cannot include types, so force using `ParameterClauseSyntax`
    // when there is more that one param.
    // If there is only one param then it is always the `Resolver`.
    if let paramList = factoryClosure?.signature?.input?.as(ClosureParamListSyntax.self), paramList.count >= 2 {
        throw RegistrationParsingError.unwrappedClosureParams(syntax: paramList)
    }

    // Register methods take a closure with resolver and arguments. Argument types must be provided
    if let closureParameters = factoryClosure?.signature?.input?.as(ParameterClauseSyntax.self) {
        let params = closureParameters.parameterList
        // The first param is the resolver, everything after that is an argument
        return try params[params.index(after: params.startIndex)..<params.endIndex].compactMap { element in
            guard let identifier = element.firstName?.text, let type = getArgumentType(arg: element)  else {
                throw RegistrationParsingError.missingArgumentType(syntax: element, name: element.firstName?.text ?? "_")
            }
            return .init(identifier: identifier, type: type)
        }
    }

    return []
}

private func getArgumentType(arg: TupleExprElementSyntax) -> String? {
    return arg.expression.as(MemberAccessExprSyntax.self)?.base?.description
        .replacingOccurrences(of: "@escaping", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func getArgumentType(arg: FunctionParameterSyntax) -> String? {
    guard let type = arg.type else {
        return nil
    }
    return type.description
        .replacingOccurrences(of: "@escaping", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

enum RegistrationParsingError: LocalizedError, SyntaxError {

    case missingArgumentType(syntax: SyntaxProtocol, name: String)
    case unwrappedClosureParams(syntax: SyntaxProtocol)
    case chainedRegistrations(syntax: SyntaxProtocol)
    case nonStaticString(syntax: SyntaxProtocol, name: String)

    var errorDescription: String? {
        switch self {
        case let .missingArgumentType(_, name):
            return "Registration for \(name) is missing a type. Type safe resolver has not been generated"
        case .unwrappedClosureParams:
            return "Registrations must wrap argument closures and add types: e.g. { (resolver: Resolver, arg: MyArg) in"
        case .chainedRegistrations:
            return "Chained registration calls are not supported"
        case let .nonStaticString(_, name):
            return "Service name must be a static string. Found: \(name)"
        }
    }

    var syntax: SyntaxProtocol {
        switch self {
        case let .missingArgumentType(syntax, _),
            let .chainedRegistrations(syntax),
            let .nonStaticString(syntax, _),
            let .unwrappedClosureParams(syntax):
            return syntax
        }
    }

}
