import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

public enum TypeSafetySourceFile {

    public static func make(
        assemblyName: String,
        extensionTarget: String,
        registrations allRegistrations: [Registration]
    ) -> SourceFileSyntax {
        let visibleRegistrations = allRegistrations.filter {
            // Exclude hidden registrations always
            $0.accessLevel != .hidden
        }
        let unnamedRegistrations = visibleRegistrations.filter { $0.name == nil }
        let namedGroups = NamedRegistrationGroup.make(from: visibleRegistrations)
        return SourceFileSyntax() {
            ExtensionDeclSyntax("""
                          // Generated from \(assemblyName)
                          extension \(extensionTarget)
                          """) {

                for registration in unnamedRegistrations {
                    if registration.getterConfig.contains(.callAsFunction) {
                        makeResolver(registration: registration, getterType: .callAsFunction)
                    }
                    if let namedGetter = registration.getterConfig.first(where: { $0.isNamed }) {
                        makeResolver(registration: registration, getterType: namedGetter)
                    }
                }
                for namedGroup in namedGroups {
                    let firstGetterConfig = namedGroup.registrations[0].getterConfig.first ?? .callAsFunction
                    makeResolver(
                        registration: namedGroup.registrations[0],
                        enumName: "\(assemblyName).\(namedGroup.enumName)",
                        getterType: firstGetterConfig
                    )
                }
            }
            if !namedGroups.isEmpty {
                makeNamedEnums(assemblyName: assemblyName, namedGroups: namedGroups)
            }
        }
    }

    /// Create the type safe resolver function for this registration
    static func makeResolver(
        registration: Registration,
        enumName: String? = nil,
        getterType: GetterConfig = .callAsFunction
    ) -> FunctionDeclSyntax {
        let modifier = registration.accessLevel == .public ? "public " : ""
        let nameInput = enumName.map { "name: \($0)" }
        let nameUsage = enumName != nil ? "name: name.rawValue" : nil
        let (argInput, argUsage) = argumentString(registration: registration)
        let inputs = [nameInput, argInput].compactMap { $0 }.joined(separator: ", ")
        let usages = ["\(registration.service).self", nameUsage, argUsage].compactMap { $0 }.joined(separator: ", ")
        let funcName: String
        switch getterType {
        case .callAsFunction:
            funcName = "callAsFunction"
        case let .identifiedGetter(name):
            funcName = name ?? TypeNamer.computedIdentifierName(type: registration.service)
        }

        return FunctionDeclSyntax("\(modifier)func \(funcName)(\(inputs)) -> \(registration.service)") {
            ForcedValueExprSyntax("self.resolve(\(raw: usages))!")
        }
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
    ) -> ExtensionDeclSyntax {
        ExtensionDeclSyntax("extension \(assemblyName)") {
            for namedGroup in namedGroups {
                let modifier = namedGroup.accessLevel == .public ? "public " : ""
                EnumDeclSyntax("\(modifier)enum \(namedGroup.enumName): String, CaseIterable") {
                    for test in namedGroup.registrations {
                        EnumCaseDeclSyntax("case \(raw: test.name!)")
                    }
                }
            }
        }
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
