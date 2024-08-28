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
                    if let namedGetter = registration.getterConfig.first(where: { $0.isNamed }) {
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
        let input = registration.namedArguments().map { "\($0.resolvedIdentifier()): \($0.functionType)" }.joined(separator: ", ")
        let usages = registration.namedArguments().map { $0.resolvedIdentifier() }.joined(separator: ", ")
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

}

extension Registration {

    /// Generate names for each argument based on the type
    func namedArguments() -> [Argument] {
        var result: [Registration.Argument] = []
        for argument in arguments {
            let indexID: String
            if (arguments.filter { $0.resolvedIdentifier() == argument.resolvedIdentifier() }).count > 1 {
                indexID = (result.filter { $0.type == argument.type }.count + 1).description
            } else {
                indexID = ""
            }
            let name = argument.resolvedIdentifier() + indexID
            result.append(Argument(identifier: name, type: argument.type))
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

    // The type to be used in functions. Closures are always expected to be escaping
    var functionType: String {
        return TypeNamer.isClosure(type: type) ? "@escaping \(type)" : type
    }
}