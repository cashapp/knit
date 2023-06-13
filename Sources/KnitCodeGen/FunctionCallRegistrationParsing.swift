//
// Copyright © Square, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax

extension FunctionCallExprSyntax {

    /// Retrieve any registrations if they exist in the function call expression.
    /// Function call expressions can contain chained function calls, and this method will parse the chain.
    func getRegistrations() -> [Registration] {
        // Collect all chained method calls
        var calledMethods = [(calledExpr: MemberAccessExprSyntax, arguments: TupleExprElementListSyntax)]()

        // Returns the base identifier token that was called
        func recurseCalledExpressions(_ funcCall: FunctionCallExprSyntax) -> TokenSyntax? {

            guard let calledExpr = funcCall.calledExpression.as(MemberAccessExprSyntax.self) else {
                return nil
            }

            // Append the method call
            calledMethods.append((calledExpr: calledExpr, arguments: funcCall.argumentList))
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

        let registerMethods = calledMethods.filter { calledExpr, _ in
            let name = calledExpr.name.text
            return name == "register" || name == "autoregister" || name == "registerAbstract"
        }

        guard registerMethods.count <= 1 else {
            fatalError("Chained registration calls are not supported")
        }

        guard let primaryRegisterMethod = registerMethods.first else {
            return []
        }

        // The primary registration (not `.implements()`)
        guard let primaryRegistration = makeRegistrationFor(
            arguments: primaryRegisterMethod.arguments,
            leadingTrivia: self.leadingTrivia,
            isForwarded: false
        ) else {
            return []
        }

        let implementsCalledMethods = calledMethods.filter { calledExpr, _ in
            calledExpr.name.text == "implements"
        }

        var forwardedRegistrations = [Registration]()

        for implementsCalledMethod in implementsCalledMethods {
            // For `.implements()` the leading trivia is attached to the Dot syntax node
            let leadingTrivia = implementsCalledMethod.calledExpr.dot.leadingTrivia

            if let forwardedRegistration = makeRegistrationFor(
                arguments: implementsCalledMethod.arguments,
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
    leadingTrivia: Trivia?,
    isForwarded: Bool
) -> Registration? {
    guard let firstParam = arguments.first?.as(TupleExprElementSyntax.self)?
        .expression.as(MemberAccessExprSyntax.self) else { return nil }
    guard firstParam.name.text == "self" else { return nil }

    let registrationText = firstParam.base!.withoutTrivia().description
    let accessLevel: AccessLevel
    if let leadingTrivia, leadingTrivia.description.contains("@digen public") {
        accessLevel = .public
    } else if let leadingTrivia, leadingTrivia.description.contains("@digen hidden") {
        accessLevel = .hidden
    } else {
        accessLevel = .internal
    }
    let name = getName(arguments: arguments)

    return Registration(service: registrationText, name: name, accessLevel: accessLevel, isForwarded: isForwarded)
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
