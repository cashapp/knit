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
        let functionName: String
        let mainActor: Bool

        if let initDecl = declaration.as(InitializerDeclSyntax.self) {
            // When the macro is applied to an initializer
            parameterClause = initDecl.signature.parameterClause
            returnType = "Self"
            makeCall = ".init"
            functionName = "make"
            mainActor = isMainActorAnnotated(attributes: initDecl.attributes)
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
            functionName = funcDecl.name.description
            mainActor = isMainActorAnnotated(attributes: funcDecl.attributes)
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
                returnType: returnType,
                functionName: functionName,
                mainActor: mainActor
            )
        ]
    }

    private static func createMakeFunction(
        params: [Param],
        resolverType: String,
        makeCall: String,
        returnType: String,
        functionName: String,
        mainActor: Bool
    ) -> DeclSyntax {
        let paramsResolved = params.map { param in
            return param.resolveCall
        }
        let paramsString = paramsResolved.joined(separator: ",\n")
        var makeArguments = ["resolver: \(resolverType)"]
        for param in params {
            if case let .argument(defaultValue) = param.hint {
                let defaultString = defaultValue.map { "= \($0)" } ?? ""
                var attributes = param.type.attributes.joined(separator: " ")
                if !attributes.isEmpty {
                    attributes = attributes + " "
                }
                makeArguments.append("\(param.name): \(attributes)\(param.type.name)" + defaultString)
            }
        }

        let makeArgumentsString = makeArguments.joined(separator: ", ")
        let mainActorAnnotation = mainActor ? "@MainActor " : ""

       return """
       \(raw: mainActorAnnotation)static func \(raw: functionName)(\(raw: makeArgumentsString)) -> \(raw: returnType) {
            return \(raw: makeCall)(
                \(raw: paramsString)
            )
       }
       """
    }

    private static func extractType(typeSyntax: TypeSyntax) throws -> TypeInformation {
        if let type = typeSyntax.as(IdentifierTypeSyntax.self) {
            return TypeInformation(name: type.description)
        } else if let type = typeSyntax.as(AttributedTypeSyntax.self) {
            let baseType = try extractType(typeSyntax: type.baseType)
            return TypeInformation(name: baseType.name, attributes: extractAttributes(list: type.attributes))
        } else if let type = typeSyntax.as(FunctionTypeSyntax.self) {
            return TypeInformation(name: "(\(type.description))")
        } else if let type = typeSyntax.as(OptionalTypeSyntax.self) {
            return TypeInformation(name: "\(type.wrappedType.description)?")
        } else if let type = typeSyntax.as(SomeOrAnyTypeSyntax.self) {
            return TypeInformation(name: type.description)
        } else if let type = typeSyntax.as(MemberTypeSyntax.self) {
            return TypeInformation(name: type.description)
        }
        throw DiagnosticsError(
            diagnostics: [.init(node: typeSyntax, message:  Error.invalidParamType(typeSyntax.description))]
        )
    }

    private static func extractAttributes(list: AttributeListSyntax) -> [String] {
        return list.compactMap { element in
            switch element {
            case let .attribute(att):
                return "@" + att.attributeName.trimmedDescription
            case .ifConfigDecl:
                return nil
            }
        }
    }

    // Identify any property wrappers that change how types are resolved
    private static func extractHint(paramSyntax: FunctionParameterSyntax) throws -> ParamHint? {
        for element in paramSyntax.attributes {
            guard case let AttributeListSyntax.Element.attribute(attribute) = element else {
                continue
            }
            let name = attribute.attributeName.description.trimmingCharacters(in: .whitespaces)
            if name == "Argument" {
                return .argument(defaultValue: extractDefault(paramSyntax: paramSyntax))
            } else if name == "Named",
               let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
               let firstString = arguments.first?.expression.as(StringLiteralExprSyntax.self)?.textContent
            {
                return .named(firstString)
            } else if name == "UseDefault" {
                guard let defaultValue = extractDefault(paramSyntax: paramSyntax) else {
                    throw DiagnosticsError(
                        diagnostics: [.init(node: paramSyntax, message:  Error.missingDefault)]
                    )
                }
                return .useDefault(defaultValue)
            }
        }
        return nil
    }

    /// Extract all of the parameters that need to be resolved
    private static func extractParams(parameterClause: FunctionParameterClauseSyntax) throws -> [Param] {
        return try parameterClause.parameters.map { paramSyntax in
            let type = try extractType(typeSyntax: paramSyntax.type)
            let name = paramSyntax.firstName.text
            let hint: ParamHint? = try extractHint(paramSyntax: paramSyntax)

            return Param(
                name: name,
                type: type,
                hint: hint
            )
        }
    }

    private static func extractDefault(paramSyntax: FunctionParameterSyntax) -> String? {
        guard let defaultValue = paramSyntax.defaultValue else {
            return nil
        }
        return defaultValue.description.replacingOccurrences(of: "= ", with: "")
    }

    private static func isMainActorAnnotated(attributes: AttributeListSyntax) -> Bool {
        for element in attributes {
            switch element {
            case let .attribute(attribute):
                if attribute.attributeName.description == "MainActor" {
                    return true
                }
            default:
                continue
            }
        }
        return false
    }

}

extension ResolvableMacro {
    struct Param {
        let name: String
        let type: TypeInformation
        let hint: ParamHint?

        var resolveCall: String {
            let knitCallName = TypeNamer.computedIdentifierName(type: type.name)
            if let hint {
                switch hint {
                case let .named(serviceName):
                    return "\(name): resolver.\(knitCallName)(name: .\(serviceName))"
                case .argument:
                    return "\(name): \(name)"
                case let .useDefault(defaultValue):
                    return "\(name): \(defaultValue)"
                }
            } else {
                return "\(name): resolver.\(knitCallName)()"
            }
        }
    }
    
    struct TypeInformation {
        let name: String
        let attributes: [String]

        init(name: String, attributes: [String] = []) {
            self.name = name
            self.attributes = attributes
        }
    }
    
    enum ParamHint: Equatable {
        case argument(defaultValue: String?)
        case named(String)
        case useDefault(String)
    }
    
    private struct HintContainer {
        var hints: [String: ParamHint]
    }
    
    internal enum Error: DiagnosticMessage {
        case missingTargetResolver
        case unsupportAttachment
        case missingReturnType
        case missingDefault
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
            case .missingDefault:
                return "@UseDefault applied to a parameter without a default value"
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
