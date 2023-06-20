import SwiftSyntax
import SwiftSyntaxBuilder

public enum UnitTestSourceFile {

    public static func make(
        importDecls: [ImportDeclSyntax],
        registrations: [Registration],
        registrationsIntoCollections: [RegistrationIntoCollection]
    ) -> SourceFileSyntax {
        SourceFileSyntax(leadingTrivia: TriviaProvider.headerTrivia) {
            for importDecl in importDecls {
                importDecl
            }

            ClassDeclSyntax("final class KnitDIRegistrationTests: XCTestCase") {

                FunctionDeclSyntax("func testRegistrations()") {

                    DeclSyntax("""
                        // In the test target for your module, please provide a static method that creates a
                        // ModuleAssembler instance for testing.
                        let assembler = makeAssemblerForTests()
                        """)

                    if registrations.isEmpty {
                        DeclSyntax("let _ = assembler.resolver")
                    } else {
                        DeclSyntax("let resolver = assembler.resolver")
                    }

                    for registration in registrations {
                        if !registration.arguments.isEmpty {
                            // TODO: The resolver needs to have access to a value to pass as an argument
                            // This will be implemented in a separate PR
                        } else if let name = registration.name {
                            FunctionCallExprSyntax(
                                "resolver.assertTypeResolves(\(raw: registration.service).self, name: \"\(raw: name)\")"
                            )
                        } else {
                            FunctionCallExprSyntax("resolver.assertTypeResolves(\(raw: registration.service).self)")
                        }
                    }

                    for (service, count) in groupByService(registrationsIntoCollections) {
                        FunctionCallExprSyntax(
                            "resolver.assertCollectionResolves(\(raw: service).self, count: \(raw: count))"
                        )
                    }
                }
            }

            // swiftlint:disable line_length
            DeclSyntax(#"""
                private extension Resolver {

                    func assertTypeResolves<T>(
                        _ type: T.Type,
                        name: String? = nil,
                        file: StaticString = #filePath,
                        line: UInt = #line
                    ) {
                        XCTAssertNotNil(
                            resolve(type, name: name),
                            "The container did not resolve the type: \\(type). Check that this type is registered correctly.",
                            file: file,
                            line: line
                        )
                    }

                    func assertCollectionResolves <T> (
                        _ type: T.Type,
                        count expectedCount: Int,
                        file: StaticString = #filePath,
                        line: UInt = #line
                    ) {
                        let actualCount = resolveCollection(type).entries.count
                        XCTAssert(
                            actualCount >= expectedCount,
                            """
                            The resolved ServiceCollection<\(type)> did not contain the expected number of services \
                            (resolved \(actualCount), expected \(expectedCount)).
                            Make sure your assembler contains a ServiceCollector behavior.
                            """,
                            file: file,
                            line: line
                        )
                    }

                }
                """#)
            // swiftlint:enable line_length
        }
    }

    /// Groups the provided registrations by service
    /// - Returns: A dictionary mapping each service to the number of times it was registered
    private static func groupByService(_ registrations: [RegistrationIntoCollection]) -> [String: Int] {
        registrations.reduce(into: [:]) { result, registration in
            let existingCount = result[registration.service] ?? 0
            result[registration.service] = existingCount + 1
        }
    }

}
