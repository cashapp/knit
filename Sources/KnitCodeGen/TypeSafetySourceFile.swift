import SwiftSyntax
import SwiftSyntaxBuilder

public enum TypeSafetySourceFile {

    public static func make(
        assemblyName: String,
        imports: [ImportDeclSyntax],
        extensionTarget: String,
        registrations: [Registration]
    ) -> SourceFileSyntax {
        let registrations = registrations.filter { $0.accessLevel != .hidden }
        let namedGroups = NamedRegistrationGroup.make(from: registrations)
        let unnamedRegistrations = registrations.filter { $0.name == nil }
        return SourceFileSyntax(leadingTrivia: TriviaProvider.headerTrivia) {
            for importItem in imports {
                importItem
            }

            ExtensionDeclSyntax("""
                          // The correct resolution of each of these types is enforced by a matching automated unit test
                          // If a type registration is missing or broken then the automated tests will fail for that PR
                          extension \(extensionTarget)
                          """) {

                for registration in unnamedRegistrations {
                    makeResolver(registration: registration, enumName: nil)
                }
                for namedGroup in namedGroups {
                    makeResolver(registration: namedGroup.registrations[0], enumName: "\(assemblyName).\(namedGroup.enumName)")
                }
            }
            if !namedGroups.isEmpty {
                makeNamedEnums(assemblyName: assemblyName, namedGroups: namedGroups)
            }
        }
    }

    /// Create the type safe resolver function for this registration
    static func makeResolver(registration: Registration, enumName: String?) -> FunctionDeclSyntax {
        let modifier = registration.accessLevel == .public ? "public " : ""
        let nameInput = enumName.map { "name: \($0)" }
        let nameUsage = enumName != nil ? "name: name.rawValue" : nil
        let (argInput, argUsage) = argumentString(registration: registration)
        let inputs = [nameInput, argInput].compactMap { $0 }.joined(separator: ", ")
        let usages = ["\(registration.service).self", nameUsage, argUsage].compactMap { $0 }.joined(separator: ", ")

        return FunctionDeclSyntax("\(modifier)func callAsFunction(\(inputs)) -> \(registration.service)") {
            ForcedValueExprSyntax("self.resolve(\(raw: usages))!")
        }
    }

    private static func argumentString(registration: Registration) -> (input: String?, usage: String?) {
        if registration.arguments.isEmpty {
            return (nil, nil)
        }
        let prefix = registration.arguments.count == 1 ? "argument:" : "arguments:"
        let input = registration.namedArguments().map { "\($0.name): \($0.type)" }.joined(separator: ", ")
        let usages = registration.namedArguments().map { $0.name }.joined(separator: ", ")
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
    func namedArguments() -> [(name: String, type: String)] {
        var result: [(name: String, type: String)] = []
        for argument in arguments {
            let indexID: String
            if (arguments.filter { $0.resolvedName() == argument.resolvedName() }).count > 1 {
                indexID = (result.filter { $0.type == argument.type }.count + 1).description
            } else {
                indexID = ""
            }
            let name = argument.resolvedName() + indexID
            result.append((name, argument.type))
        }
        return result
    }

}

private extension Registration.Argument {

    func resolvedName() -> String {
        if let name {
            return name
        }
        if type.uppercased() == type {
            return type.lowercased()
        }
        return type.prefix(1).lowercased() + type.dropFirst()
    }

}
