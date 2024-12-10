//  Created by Alexander Skorulis on 28/3/2024.

import Foundation
import KnitCodeGen
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ResolvableMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let resolverTypeArg = node.attributeName.as(IdentifierTypeSyntax.self)?.genericArgumentClause?.arguments.first else {
            throw DiagnosticsError(
                diagnostics: [.init(node: node, message:  Error.missingResolverType)]
            )
        }
        let resolverType = resolverTypeArg.description
        var arguments: Set<String> = []
        var names: [String: String] = [:]
        if let nodeArgs = node.arguments?.as(LabeledExprListSyntax.self) {
            arguments = parseArguments(node: nodeArgs)
            names = parseNames(node: nodeArgs)
        }
        
        let parameterClause: FunctionParameterClauseSyntax
        let returnType: String
        let makeCall: String
        if let initDecl = declaration.as(InitializerDeclSyntax.self) {
            parameterClause = initDecl.signature.parameterClause
            returnType = "Self"
            makeCall = ".init"
        } else if let funcDecl = declaration.as(FunctionDeclSyntax.self) {
            parameterClause = funcDecl.signature.parameterClause
            guard let ret = funcDecl.signature.returnClause?.type.as(IdentifierTypeSyntax.self)?.name.text else {
                throw DiagnosticsError(
                    diagnostics: [.init(node: funcDecl, message:  Error.missingReturnType)]
                )
            }
            let isStatic = funcDecl.modifiers.contains { $0.name.text == "static" }
            guard isStatic else {
                throw DiagnosticsError(
                    diagnostics: [.init(node: funcDecl, message:  Error.nonInitializerOrFunc)]
                )
            }
            returnType = ret
            makeCall = funcDecl.name.text
        } else {
            throw DiagnosticsError(
                diagnostics: [.init(node: node, message:  Error.nonInitializerOrFunc)]
            )
        }
        
        let params = try parameterClause.parameters.map { paramSyntax in
            let type = try extractType(typeSyntax: paramSyntax.type)
            let name = paramSyntax.firstName.text
            let hint: ParamHint?
            if arguments.contains(name) {
                arguments.remove(name)
                hint = .argument
            } else if let serviceName = names[name] {
                hint = .named(serviceName)
                names.removeValue(forKey: name)
            } else {
                hint = nil
            }
            
            return Param(
                name: name,
                type: type,
                hint: hint,
                defaultValue: extractDefault(paramSyntax: paramSyntax)
            )
        }
        if let unused = arguments.first {
            throw DiagnosticsError(
                diagnostics: [.init(node: node, message:  Error.unusedArgument(unused))]
            )
        }
        if let unused = names.first?.key {
            throw DiagnosticsError(
                diagnostics: [.init(node: node, message:  Error.unusedName(unused))]
            )
        }
        
        let paramsResolved = params.map { param in
            return resolveCall(param: param)
        }
        let paramsString = paramsResolved.joined(separator: ",\n")
        var makeArguments = ["resolver: \(resolverType)"]
        for param in params {
            if param.isArgument {
                makeArguments.append("\(param.name): \(param.type.name)")
            }
        }
        
        let makeArgumentsString = makeArguments.joined(separator: ", ")
        
        return [
           """
           static func make(\(raw: makeArgumentsString)) -> \(raw: returnType) {
                return \(raw: makeCall)(
                    \(raw: paramsString)
                )
           }
           """
           ]
    }
    
    private static func resolveCall(param: Param) -> String {
        if param.isArgument {
            return "\(param.name): \(param.name)"
        }
        return param.resolveCall
    }
    
    private static func parseArguments(node: LabeledExprListSyntax) -> Set<String> {
        guard let args = node.first(where: { $0.label?.description == "arguments"})?.expression.as(ArrayExprSyntax.self)?.elements else {
            return []
        }
        let argsArray = args.compactMap { arrayElement in
            return arrayElement.expression.as(StringLiteralExprSyntax.self)?.textContent
        }
        return Set(argsArray)
    }
    
    static func parseNames(node: LabeledExprListSyntax) -> [String: String] {
        guard let names = node.first(where: { $0.label?.description == "names"})?
            .expression.as(DictionaryExprSyntax.self)?.content
            .as(DictionaryElementListSyntax.self)
        else {
            return [:]
        }
        var result: [String: String] = [:]
        for element in names {
            guard let key = element.key.as(StringLiteralExprSyntax.self)?.textContent,
                  let value = element.value.as(StringLiteralExprSyntax.self)?.textContent else {
                continue
            }
            result[key] = value
        }
        
        return result
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
    
    private static func extractDefault(paramSyntax: FunctionParameterSyntax) -> String? {
        guard let defaultValue = paramSyntax.defaultValue else {
            return nil
        }
        return defaultValue.description.replacingOccurrences(of: "= ", with: "")
    }
    
}

private extension ResolvableMacro {
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
            } else if let hint, case let ParamHint.named(serviceName) = hint {
                return "\(name): resolver.\(knitCallName)(name: .\(serviceName))"
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
    
    enum Error: DiagnosticMessage {
        case missingResolverType
        case nonInitializerOrFunc
        case expectedArgumentName
        case expectedExpression
        case missingReturnType
        case invalidParamType(String)
        case unusedArgument(String)
        case unusedName(String)
        
        var message: String {
            switch self {
            case .missingResolverType:
                return "@Resolvable requires a generic parameter"
            case .nonInitializerOrFunc:
                return "@Resolvable can only be used on init declarations or static functions"
            case let .invalidParamType(string):
                return "Unexpected parameter type: \(string)"
            case .expectedArgumentName:
                return "Expected Argument name"
            case .expectedExpression:
                return "Expected expression"
            case .missingReturnType:
                return "Could not identify function return type"
            case let .unusedArgument(name):
                return "Argument: '\(name)' was declared but is not a parameter"
            case let .unusedName(name):
                return "Name: '\(name)' was declared but is not a parameter"
            }
        }
        
        var diagnosticID: MessageID {
            MessageID(domain: "ResolvableMacro", id: message)
        }
        
        var severity: DiagnosticSeverity { .error }
    }
}

// MARK: - Swift Syntax Extensions

private extension StringLiteralExprSyntax {
    
    var textContent: String? {
        segments.first?.as(StringSegmentSyntax.self)?.content
            .description.trimmingCharacters(in: .init(charactersIn: "\""))
    }
}
