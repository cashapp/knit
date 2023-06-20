import SwiftSyntax
import SwiftSyntaxBuilder

public enum UnitTestSourceFile {

    public static func make(
        importDecls: [ImportDeclSyntax],
        setupCodeBlock: CodeBlockItemListSyntax?,
        registrations: [Registration],
        registrationsIntoCollections: [RegistrationIntoCollection]
    ) -> SourceFileSyntax {
        let withArguments = registrations.filter { !$0.arguments.isEmpty }
        let hasArguments = !withArguments.isEmpty
        return SourceFileSyntax(leadingTrivia: TriviaProvider.headerTrivia) {
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

                    if hasArguments {
                        DeclSyntax("""
                            // In the test target for your module, please provide a static method that provides
                            // an instance of KnitRegistrationTestArguments
                            let args: KnitRegistrationTestArguments = makeArgumentsForTests()
                            """)
                    }

                    if registrations.isEmpty {
                        DeclSyntax("let _ = assembler.resolver")
                    } else {
                        DeclSyntax("let resolver = assembler.resolver")
                    }

                    for registration in registrations {
                        makeAssertCall(registration: registration)
                    }

                    for (service, count) in groupByService(registrationsIntoCollections) {
                        FunctionCallExprSyntax(
                            "resolver.assertCollectionResolves(\(raw: service).self, count: \(raw: count))"
                        )
                    }
                }
            }

            if hasArguments {
                makeArgumentStruct(registrations: registrations)
            }

            // swiftlint:disable line_length
            ExtensionDeclSyntax("private extension Resolver") {
                // This assert is only needed if there are registrations without arguments
                if registrations.count > withArguments.count {
                    makeTypeAssert()
                }

                // This assert is only needed if there are registrations with arguments
                if hasArguments {
                    makeResultAssert()
                }

                if !groupByService(registrationsIntoCollections).isEmpty {
                    makeCollectionAssert()
                }
            }
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

    /// Generate a function call to test a single registration resolves
    static func makeAssertCall(registration: Registration) -> FunctionCallExprSyntax {
        if !registration.arguments.isEmpty {
            let argParams = argumentParams(registration: registration)
            let nameParam = registration.name.map { "name: \"\($0)\""}
            let params = ["\(registration.service).self", nameParam, argParams].compactMap { $0 }.joined(separator: ", ")
            return FunctionCallExprSyntax(
                "resolver.assertTypeResolved(resolver.resolve(\(raw: params)))"
            )
        } else if let name = registration.name {
            return FunctionCallExprSyntax(
                "resolver.assertTypeResolves(\(raw: registration.service).self, name: \"\(raw: name)\")"
            )
        } else {
            return FunctionCallExprSyntax("resolver.assertTypeResolves(\(raw: registration.service).self)")
        }
    }

    private static func makeCollectionAssert() -> FunctionDeclSyntax {
        let string = #"""
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
        """#
        return FunctionDeclSyntax(stringLiteral: string)
    }

    /// Generate a function to assert that a type can be resolved
    private static func makeTypeAssert() -> FunctionDeclSyntax {
        let string = """
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
        """
        return FunctionDeclSyntax(stringLiteral: string)
    }

    /// Generate a function to assert that a value resolved correctly
    private static func makeResultAssert() -> FunctionDeclSyntax {
        let string = """
        func assertTypeResolved<T>(
            _ result: T?,
            file: StaticString = #filePath,
            line: UInt = #line
        ) {
            XCTAssertNotNil(
                result,
                "The container did not resolve the type: \\(T.self). Check that this type is registered correctly.",
                file: file,
                line: line
            )
        }
        """
        return FunctionDeclSyntax(stringLiteral: string)
    }

    /// Generate code for a struct that contains all of the parameters used to resolve services
    static func makeArgumentStruct(registrations: [Registration]) -> StructDeclSyntax {
        let fields = registrations.flatMap { $0.serviceNamedArguments() }
        var seen: Set<String> = []
        // Make sure duplicate parameters don't get created
        let uniqueFields = fields.filter {
            let key = "\($0.0)-\($0.1)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }

        return StructDeclSyntax("struct KnitRegistrationTestArguments") {
            for field in uniqueFields {
                DeclSyntax("let \(raw: field.0): \(raw: field.1)")
            }
        }
    }

    private static func argumentParams(registration: Registration) -> String {
        if registration.arguments.isEmpty {
            fatalError("Should only be called for registrations with arguments")
        }
        let prefix = registration.arguments.count == 1 ? "argument:" : "arguments:"
        let params = registration.serviceNamedArguments().map { "args.\($0.name)" }.joined(separator: ", ")
        return "\(prefix) \(params)"
    }

}

private extension Registration {

    /// Argument names prefixed with the service name. Provides additional collision safety.
    func serviceNamedArguments() -> [(name: String, type: String)] {
        return namedArguments().map { (name, type) in
            let serviceName = self.service.prefix(1).lowercased() + self.service.dropFirst()
            let capitalizedName = name.prefix(1).uppercased() + name.dropFirst()
            return (serviceName + capitalizedName, type)
        }
    }

}
