//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

public enum TypeSafetySourceFile {

    public static func make(
        from config: Configuration
    ) throws -> SourceFileSyntax {
        let visibleRegistrations = config.registrations.filter {
            // Exclude hidden registrations always
            $0.accessLevel != .hidden && $0.accessLevel != .ignore
        }
        let unnamedRegistrations = visibleRegistrations.filter { $0.name == nil }
        let namedGroups = NamedRegistrationGroup.make(from: visibleRegistrations)
        return try SourceFileSyntax() {
            try ExtensionDeclSyntax("""
                          /// Generated from ``\(raw: config.assemblyName)``
                          extension \(raw: config.targetResolver)
                          """) {

                for registration in unnamedRegistrations {
                    if registration.getterConfig.contains(.callAsFunction) {
                        try makeResolver(registration: registration, getterType: .callAsFunction)
                    }
                    if let namedGetter = registration.namedGetterConfig {
                        try makeResolver(registration: registration, getterType: namedGetter)
                    }
                }
                for namedGroup in namedGroups {
                    let firstGetterConfig = namedGroup.registrations[0].getterConfig.first ?? .callAsFunction
                    try makeResolver(
                        registration: namedGroup.registrations[0],
                        enumName: "\(config.assemblyName).\(namedGroup.enumName)",
                        getterType: firstGetterConfig
                    )
                }
            }
            if !namedGroups.isEmpty {
                try makeNamedEnums(assemblyName: config.assemblyName, namedGroups: namedGroups)
            }
            if let defaultOverrides = try makeDefaultOverrideExtensions(config: config) {
                defaultOverrides
            }
            try makePerformanceExtension(config: config)
        }
    }

    /// Create the type safe resolver function for this registration
    static func makeResolver(
        registration: Registration,
        enumName: String? = nil,
        getterType: GetterConfig = .callAsFunction
    ) throws -> DeclSyntaxProtocol {
        var modifier = ""
        if let spi = registration.spi {
            modifier += "@_spi(\(spi)) "
        }
        if let concurrencyModifier = registration.concurrencyModifier {
            modifier += "\(concurrencyModifier) "
        }
        modifier += registration.accessLevel == .public ? "public " : ""
        let nameInput = enumName.map { "name: \($0)" }
        let nameUsage = enumName != nil ? "name: name.rawValue" : nil
        let (argInput, argUsage) = argumentString(registration: registration)
        let inputs = [
            nameInput,
            argInput,
            // Add call-site context params with default values to forward to the error messaging
            "file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line"
        ].compactMap { $0 }.joined(separator: ", ")
        let usages = ["\(registration.service).self", nameUsage, argUsage].compactMap { $0 }.joined(separator: ", ")
        let funcName: String
        switch getterType {
        case .callAsFunction:
            funcName = "callAsFunction"
        case let .identifiedGetter(name):
            funcName = name ?? TypeNamer.computedIdentifierName(type: registration.service)
        }

        let function = try FunctionDeclSyntax("\(raw: modifier)func \(raw: funcName)(\(raw: inputs)) -> \(raw: registration.service)") {
            "knitUnwrap(resolve(\(raw: usages)), callsiteFile: file, callsiteFunction: function, callsiteLine: line)"
        }

        // Wrap the output in an #if where needed
        guard let ifConfigCondition = registration.ifConfigCondition else {
            return function
        }
        let codeBlock = CodeBlockItemListSyntax([.init(item: .init(function))])
        let clause = IfConfigClauseSyntax(
            poundKeyword: .poundIfToken(),
            condition: ifConfigCondition,
            elements: .statements(codeBlock)
        )
        return IfConfigDeclSyntax(clauses: [clause])
    }

    private static func argumentString(registration: Registration) -> (input: String?, usage: String?) {
        if registration.arguments.isEmpty {
            return (nil, nil)
        }
        let prefix = registration.arguments.count == 1 ? "argument:" : "arguments:"
        let identifiedArguments = registration.uniquelyIdentifiedArguments()
        let input = identifiedArguments.map { "\($0.resolvedIdentifier()): \($0.type)" }.joined(separator: ", ")
        let usages = identifiedArguments.map { $0.resolvedIdentifier() }.joined(separator: ", ")
        return (input, "\(prefix) \(usages)")
    }

    private static func makeNamedEnums(
        assemblyName: String,
        namedGroups: [NamedRegistrationGroup]
    ) throws -> ExtensionDeclSyntax {
        try ExtensionDeclSyntax("extension \(raw: assemblyName)") {
            for namedGroup in namedGroups {
                let modifier = namedGroup.accessLevel == .public ? "public " : ""
                try EnumDeclSyntax("\(raw: modifier)enum \(raw: namedGroup.enumName): String, CaseIterable") {
                    for test in namedGroup.registrations {
                        "case \(raw: test.name!)" as DeclSyntax
                    }
                }
            }
        }
    }

    private static func makeDefaultOverrideExtensions(
        config: Configuration
    ) throws -> CodeBlockItemListSyntax? {
        // Only `FakeAssembly` types should automatically generate the default override extensions
        guard config.assemblyType == .fakeAssembly else {
            return nil
        }

        return try CodeBlockItemListSyntax {
            for replacedType in config.replaces {
                try ExtensionDeclSyntax(
                    extendedType: TypeSyntax("\(raw: replacedType)"),
                    inheritanceClause: InheritanceClauseSyntax(inheritedTypesBuilder: {
                        InheritedTypeSyntax(type: MemberTypeSyntax(
                            // explicitly qualifying the type with the Knit module fixes a warning for Swift 6
                            baseType: IdentifierTypeSyntax(name: "Knit"),
                            name: TokenSyntax(stringLiteral: "DefaultModuleAssemblyOverride")
                        ))
                    }),
                    memberBlockBuilder: {
                        try TypeAliasDeclSyntax("public typealias OverrideType = \(raw: config.assemblyName)")
                    }
                )
            }
        }
        .with(
            \.leadingTrivia,
             """
             /// For assemblies that conform to `FakeAssembly`, Knit automatically generates
             /// default overrides for all other types it replaces.

             """
        )
    }

    private static func makePerformanceExtension(config: Configuration) throws -> ExtensionDeclSyntax {
        let accessorBlock: AccessorBlockSyntax
        let isAutoInit: Bool
        if config.assemblyType == .abstractAssembly {
            accessorBlock = AccessorBlockSyntax(
                accessors: .getter(.init(stringLiteral: "[.autoInit, .abstract]"))
            )
            isAutoInit = true
        } else if config.assemblyType == .autoInitAssembly || config.assemblyType == .fakeAssembly {
            accessorBlock = AccessorBlockSyntax(
                accessors: .getter(.init(stringLiteral: "[.autoInit]"))
            )
            isAutoInit = true
        }
        else {
            accessorBlock = AccessorBlockSyntax(
                accessors: .getter(.init(stringLiteral: "[]"))
            )
            isAutoInit = false
        }

        return try ExtensionDeclSyntax(
            extendedType: TypeSyntax(stringLiteral: config.assemblyName),
            memberBlockBuilder: {
                VariableDeclSyntax.makeVar(
                    keywords: [.public, .static],
                    name: "_assemblyFlags",
                    type: "[ModuleAssemblyFlags]",
                    accessorBlock: accessorBlock
                )
                if isAutoInit {
                    try FunctionDeclSyntax("public static func _autoInstantiate() -> (any ModuleAssembly)? { \(raw: config.assemblyName)() }")
                } else {
                    try FunctionDeclSyntax("public static func _autoInstantiate() -> (any ModuleAssembly)? { nil }")
                }
            }
        )
    }

}

extension Registration {

    /// Regenerate identifiers for the arguments array with uniqueness.
    /// If multiple arguments have the same resolved identifier, an index will be appended to the identifier to make it unique.
    func uniquelyIdentifiedArguments() -> [Argument] {
        var result: [Registration.Argument] = []
        for (offset, argument) in arguments.enumerated() {
            let indexID: String
            // Check for any collisions across all arguments
            if (arguments.filter { $0.resolvedIdentifier() == argument.resolvedIdentifier() }).count > 1 {
                // To find the index of this argument's identifier, only look at the sub array of arguments
                // that came before the current argument.
                // Also we are using the original arguments array, not the result array which has modified identifiers
                // that will no longer match.
                let subArrayArguments = arguments[0..<offset]
                indexID = (subArrayArguments.filter { $0.resolvedIdentifier() == argument.resolvedIdentifier() }.count + 1).description
            } else {
                // No collisions
                indexID = ""
            }
            // Append an index number (might be empty) to the identifier
            let identifier = argument.resolvedIdentifier() + indexID
            result.append(Argument(identifier: identifier, type: argument.type))
        }
        return result
    }
}

extension Registration.Argument {

    /// Determine the identifier for the Registration Argument.
    func resolvedIdentifier() -> String {
        switch identifier {
        case let .fixed(value):
            return value
        case .computed:
            return TypeNamer.computedIdentifierName(type: type)
        }
    }

}
