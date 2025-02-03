//
// Copyright © Block, Inc. All rights reserved.
//

import KnitCodeGen
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Macro which can be applied to the struct for the auto init
public struct ResolvableStructMacro: ExtensionMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
        providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
        let resolverType = try ResolvableMacro.extractResolverType(node: node)

        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw DiagnosticsError(
                diagnostics: [.init(node: node, message:  Error.unsupportAttachment)]
            )
        }
        let params = try extractMembers(structDecl: structDecl)

        return [
            try createExtension(
                name: structDecl.name.text,
                contents: ResolvableMacro.createMakeFunction(
                    params: params,
                    resolverType: resolverType,
                    makeCall: ".init",
                    returnType: "Self"
                )
            )
        ]
    }

    private static func createExtension(
        name: String,
        contents: DeclSyntax
    ) throws -> ExtensionDeclSyntax {
        return try ExtensionDeclSyntax("extension \(raw: name) { \(contents) }")
    }

    private static func extractMembers(structDecl: StructDeclSyntax) throws -> [ResolvableMacro.Param] {
        return structDecl.memberBlock.members.compactMap { item -> ResolvableMacro.Param? in
            guard let varDecl = item.decl.as(VariableDeclSyntax.self) else {
                return nil
            }
            if varDecl.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static)}) {
                return nil // Don't resolve static values
            }
            guard let binding = varDecl.bindings.first else {
                return nil
            }
            if binding.accessorBlock != nil {
                return nil // Don't resolve computed values
            }
            if binding.initializer != nil {
                return nil // Don't resolve initialized values
            }
            guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.trimmedDescription else {
                return nil
            }
            guard let type = binding.typeAnnotation?.type.as(IdentifierTypeSyntax.self)?.name.text else {
                return nil
            }

            return ResolvableMacro.Param(
                name: name,
                type: .init(name: type),
                hint: nil,
                defaultValue: nil
            )
        }
    }
}

extension ResolvableStructMacro {
    internal enum Error: DiagnosticMessage {
        case unsupportAttachment

        var message: String {
            switch self {
            case .unsupportAttachment:
                return "@ResolvableStruct can only be applied to structs"
            }
        }

        var diagnosticID: MessageID {
            MessageID(domain: "ResolvableStructMacro", id: message)
        }

        var severity: DiagnosticSeverity { .error }
    }
}
