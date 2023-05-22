import SwiftSyntax
import SwiftSyntaxBuilder

public enum TypeSafetySourceFile {

    public static func make(
        assemblyName: String,
        imports: [ImportDeclSyntax],
        extensionTarget: String,
        registrations: [Registration]
    ) -> SourceFileSyntax {
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
                    let modifier = registration.accessLevel == .public ? "public " : ""
                    FunctionDeclSyntax("\(modifier)func callAsFunction() -> \(registration.service)") {
                        ForcedValueExprSyntax("self.resolve(\(raw: registration.service).self)!")
                    }
                }
                for namedGroup in namedGroups {
                    let modifier = namedGroup.accessLevel == .public ? "public " : ""
                    // swiftlint:disable:next line_length
                    FunctionDeclSyntax("\(modifier)func callAsFunction(named: \(assemblyName).\(namedGroup.enumName)) -> \(namedGroup.service)") {
                        ForcedValueExprSyntax("self.resolve(\(raw: namedGroup.service).self, name: named.rawValue)!")
                    }
                }
            }
            if !namedGroups.isEmpty {
                makeNamedEnums(assemblyName: assemblyName, namedGroups: namedGroups)
            }

        }
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
