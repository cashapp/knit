//
// Copyright © Block, Inc. All rights reserved.
//

import KnitCodeGen
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct ResolvableMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let resolverType = try extractTargetResolver(node: node)

        let parameterClause: FunctionParameterClauseSyntax
        let returnType: String
        let makeCall: String

        if let initDecl = declaration.as(InitializerDeclSyntax.self) {
            // When the macro is applied to an initializer
            parameterClause = initDecl.signature.parameterClause
            returnType = "Self"
            makeCall = ".init"
        } else if let funcDecl = declaration.as(FunctionDeclSyntax.self) {
            // When the macro is applied to a static function
            parameterClause = funcDecl.signature.parameterClause
            guard let ret = funcDecl.signature.returnClause?.type.as(IdentifierTypeSyntax.self)?.name.text else {
                throw DiagnosticsError(
                    diagnostics: [.init(node: funcDecl, message:  Error.missingReturnType)]
                )
            }
            let isStatic = funcDecl.modifiers.contains { $0.name.text == "static" }
            guard isStatic else {
                throw DiagnosticsError(
                    diagnostics: [.init(node: funcDecl, message:  Error.unsupportAttachment)]
                )
            }
            returnType = ret
            makeCall = funcDecl.name.text
        } else {
            throw DiagnosticsError(
                diagnostics: [.init(node: node, message:  Error.unsupportAttachment)]
            )
        }

        let params = try extractParams(parameterClause: parameterClause)

        return [
            createMakeFunction(
                params: params,
                resolverType: resolverType,
                makeCall: makeCall,
                returnType: returnType
            )
        ]
    }

    private static func createMakeFunction(
        params: [Param],
        resolverType: String,
        makeCall: String,
        returnType: String
    ) -> DeclSyntax {
        let paramsResolved = params.map { param in
            return param.resolveCall
        }
        let paramsString = paramsResolved.joined(separator: ",\n")
        var makeArguments = ["resolver: \(resolverType)"]
        for param in params {
            if param.isArgument {
                makeArguments.append("\(param.name): \(param.type.name)")
            }
        }

        let makeArgumentsString = makeArguments.joined(separator: ", ")

       return """
       static func make(\(raw: makeArgumentsString)) -> \(raw: returnType) {
            return \(raw: makeCall)(
                \(raw: paramsString)
            )
       }
       """
    }

    private static func extractType(typeSyntax: TypeSyntax) throws -> TypeInformation {
        if let type = typeSyntax.as(IdentifierTypeSyntax.self) {
            return TypeInformation(name: type.name.text)
        } else if let type = typeSyntax.as(AttributedTypeSyntax.self) {
            let baseType = try extractType(typeSyntax: type.baseType)
            return TypeInformation(name: baseType.name)
        } else if let type = typeSyntax.as(FunctionTypeSyntax.self) {
            return TypeInformation(name: "(\(type.description))")
        }
        throw DiagnosticsError(
            diagnostics: [.init(node: typeSyntax, message:  Error.invalidParamType(typeSyntax.description))]
        )
    }

    // Identify any property wrappers that change how types are resolved
    private static func extractHint(paramSyntax: FunctionParameterSyntax) -> ParamHint? {
        for element in paramSyntax.attributes {
            guard case let AttributeListSyntax.Element.attribute(attribute) = element else {
                continue
            }
            let name = attribute.attributeName.description.trimmingCharacters(in: .whitespaces)
            if name == "Argument" {
                return .argument
            } else if name == "Named",
               let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
               let firstString = arguments.first?.expression.as(StringLiteralExprSyntax.self)?.textContent
            {
                return .named(firstString)
            }
        }
        return nil
    }

    /// Extract all of the parameters that need to be resolved
    private static func extractParams(parameterClause: FunctionParameterClauseSyntax) throws -> [Param] {
        return try parameterClause.parameters.map { paramSyntax in
            let type = try extractType(typeSyntax: paramSyntax.type)
            let name = paramSyntax.firstName.text
            let hint: ParamHint? = extractHint(paramSyntax: paramSyntax)

            return Param(
                name: name,
                type: type,
                hint: hint,
                defaultValue: extractDefault(paramSyntax: paramSyntax)
            )
        }
    }

    private static func extractDefault(paramSyntax: FunctionParameterSyntax) -> String? {
        guard let defaultValue = paramSyntax.defaultValue else {
            return nil
        }
        return defaultValue.description.replacingOccurrences(of: "= ", with: "")
    }
    
}

extension ResolvableMacro {
    struct Param {
        let name: String
        let type: TypeInformation
        let hint: ParamHint?
        let defaultValue: String?
        
        var isArgument: Bool { hint == .argument }
        
        var resolveCall: String {
            let knitCallName = TypeNamer.computedIdentifierName(type: type.name)
            if let defaultValue {
                return "\(name): \(defaultValue)"
            } else if let hint {
                switch hint {
                case let .named(serviceName):
                    return "\(name): resolver.\(knitCallName)(name: .\(serviceName))"
                case .argument:
                    return "\(name): \(name)"
                }
            } else {
                return "\(name): resolver.\(knitCallName)()"
            }
        }
    }
    
    struct TypeInformation {
        let name: String
        
        init(name: String) {
            self.name = name
        }
    }
    
    enum ParamHint: Equatable {
        case argument
        case named(String)
    }
    
    private struct HintContainer {
        var hints: [String: ParamHint]
    }
    
    internal enum Error: DiagnosticMessage {
        case missingTargetResolver
        case unsupportAttachment
        case missingReturnType
        case invalidParamType(String)
        
        var message: String {
            switch self {
            case .missingTargetResolver:
                return "@Resolvable requires a generic TargetResolver parameter"
            case .unsupportAttachment:
                return "@Resolvable can only be used on init declarations or static functions"
            case let .invalidParamType(string):
                return "Unexpected parameter type: \(string)"
            case .missingReturnType:
                return "Static function must declare a return type"
            }
        }
        
        var diagnosticID: MessageID {
            MessageID(domain: "ResolvableMacro", id: message)
        }
        
        var severity: DiagnosticSeverity { .error }
    }
}

extension ResolvableMacro {
    static func extractTargetResolver(node: AttributeSyntax) throws -> String {
        guard let resolverTypeArg = node.attributeName.as(IdentifierTypeSyntax.self)?.genericArgumentClause?.arguments.first else {
            throw DiagnosticsError(
                diagnostics: [.init(node: node, message:  Error.missingTargetResolver)]
            )
        }
        return resolverTypeArg.description
    }
}

// MARK: - Swift Syntax Extensions

private extension StringLiteralExprSyntax {
    
    var textContent: String? {
        segments.first?.as(StringSegmentSyntax.self)?.content
            .description.trimmingCharacters(in: .init(charactersIn: "\""))
    }
}
