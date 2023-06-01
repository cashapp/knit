//
// Copyright © Square, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax

extension FunctionCallExprSyntax {

    /// Retrieve a registration if it exists in the function call expression.
    /// Function call expressions can contain chained function calls, and this method will parse the chain.
    func getRegistration() -> Registration? {
        // Collect all chained method calls
        var calledMethods = [(methodName: TokenSyntax, arguments: TupleExprElementListSyntax)]()

        // Returns the base identifier token that was called
        func recurseCalledExpressions(_ funcCall: FunctionCallExprSyntax) -> TokenSyntax? {

            guard let calledExpr = funcCall.calledExpression.as(MemberAccessExprSyntax.self) else {
                return nil
            }

            // Append the method call
            calledMethods.append((methodName: calledExpr.name, arguments: funcCall.argumentList))
            if let identifierToken = calledExpr.base?.as(IdentifierExprSyntax.self)?.identifier {
                return identifierToken
            } else {
                let innerFunctionCall = calledExpr.base!.as(FunctionCallExprSyntax.self)!
                return recurseCalledExpressions(innerFunctionCall)
            }
        }

        // Kick off recursion with the current function call
        guard let baseIdentfier = recurseCalledExpressions(self) else {
            return nil
        }

        // The final base identifier must be the "container" local argument
        guard baseIdentfier.text == "container" else {
            return nil
        }

        let registerMethods = calledMethods.filter { methodName, _ in
            methodName.text == "register" || methodName.text == "autoregister"
        }

        guard registerMethods.count <= 1 else {
            fatalError("Chained registration calls are not supported")
        }

        if let registerMethod = registerMethods.first {
            guard let firstParam = registerMethod.arguments.first?.as(TupleExprElementSyntax.self)?
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
            let name = getName(arguments: registerMethod.arguments)

            return .init(service: registrationText, name: name, accessLevel: accessLevel)
        }

        return nil
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

}
