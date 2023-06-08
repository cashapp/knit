import SwiftSyntax
import SwiftSyntaxBuilder

public enum TypeSafetySourceFile {

    public static func make(
        assemblyName: String,
        imports: [ImportDeclSyntax],
        extensionTarget: String,
        registrations: [Registration]
    ) throws -> SourceFileSyntax {
        let registrations = registrations.filter { $0.accessLevel != .hidden }
        let namedGroups = NamedRegistrationGroup.make(from: registrations)
        let unnamedRegistrations = registrations.filter { $0.name == nil }
        return try SourceFileSyntax(leadingTrivia: TriviaProvider.headerTrivia) {
            for importItem in imports {
                importItem
            }

            try ExtensionDeclSyntax("""
                          // The correct resolution of each of these types is enforced by a matching automated unit test
                          // If a type registration is missing or broken then the automated tests will fail for that PR
                          extension \(raw: extensionTarget)
                          """) {

                for registration in unnamedRegistrations {
                    let modifier = registration.accessLevel == .public ? "public " : ""
                    try FunctionDeclSyntax("\(raw: modifier)func callAsFunction() -> \(raw: registration.service)") {
                        ForcedValueExprSyntax(ExprSyntax("self.resolve(\(raw: registration.service).self)!"))!
                    }
                }
                for namedGroup in namedGroups {
                    let modifier = namedGroup.accessLevel == .public ? "public " : ""
                    // swiftlint:disable:next line_length
                    try FunctionDeclSyntax("\(raw: modifier)func callAsFunction(named: \(raw: assemblyName).\(raw: namedGroup.enumName)) -> \(raw: namedGroup.service)") {
                        ForcedValueExprSyntax(ExprSyntax("self.resolve(\(raw: namedGroup.service).self, name: named.rawValue)!"))!
                    }
                }
            }
            if !namedGroups.isEmpty {
                try makeNamedEnums(assemblyName: assemblyName, namedGroups: namedGroups)
            }

        }
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
                        EnumCaseDeclSyntax(DeclSyntax("case \(raw: test.name!)"))!
                    }
                }
            }
        }
    }

}
