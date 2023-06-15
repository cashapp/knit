import SwiftSyntax
import SwiftSyntaxBuilder

public enum UnitTestSourceFile {

    public static func make(
        importDecls: [ImportDeclSyntax],
        setupCodeBlock: CodeBlockItemListSyntax?,
        registrations: [Registration]
    ) -> SourceFileSyntax {
        SourceFileSyntax(leadingTrivia: TriviaProvider.headerTrivia) {
            for importDecl in importDecls {
                importDecl
            }

            ClassDeclSyntax("final class KnitDIRegistrationTests: XCTestCase") {

                FunctionDeclSyntax("func testRegistrations()") {

                    if let setupCodeBlock {
                        setupCodeBlock
                    }
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
                        if let name = registration.name {
                            FunctionCallExprSyntax(
                                "resolver.assertTypeResolves(\(raw: registration.service).self, name: \"\(raw: name)\")"
                            )
                        } else {
                            FunctionCallExprSyntax("resolver.assertTypeResolves(\(raw: registration.service).self)")
                        }

                    }
                }
            }

            // swiftlint:disable line_length
            DeclSyntax("""
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

                }
                """)
            // swiftlint:enable line_length
        }
    }

}
