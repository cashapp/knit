//
// Copyright © Block, Inc. All rights reserved.
//

import SwiftSyntax
import SwiftSyntaxBuilder

public enum UnitTestSourceFile {

    public static func make(
        configuration: Configuration
    ) throws -> SourceFileSyntax {
        let withArguments = configuration.registrations.filter { !$0.arguments.isEmpty }
        let hasArguments = !withArguments.isEmpty
        return try SourceFileSyntax() {
            try ClassDeclSyntax("final class \(raw: configuration.moduleName)RegistrationTests: XCTestCase") {

                try FunctionDeclSyntax("func testRegistrations()") {

                    DeclSyntax("""
                        // In the test target for your module, please provide a static method that creates a
                        // ModuleAssembler instance for testing.
                        let assembler = \(raw: configuration.assemblyName).makeAssemblerForTests()
                        """)

                    if hasArguments {
                        DeclSyntax("""
                            // In the test target for your module, please provide a static method that provides
                            // an instance of \(raw: configuration.moduleName)RegistrationTestArguments
                            let args: \(raw: configuration.moduleName)RegistrationTestArguments = \(raw: configuration.assemblyName).makeArgumentsForTests()
                            """)
                    }

                    if configuration.registrations.isEmpty && configuration.registrationsIntoCollections.isEmpty {
                        DeclSyntax("let _ = assembler.resolver")
                    } else {
                        DeclSyntax("let resolver = assembler.resolver")
                    }

                    for registration in configuration.registrations {
                        makeAssertCall(registration: registration)
                    }

                    for (service, count) in groupByService(configuration.registrationsIntoCollections) {
                        ExprSyntax(
                            "resolver.assertCollectionResolves(\(raw: service).self, count: \(raw: count))"
                        )
                    }
                }
            }

            if hasArguments {
                try makeArgumentStruct(registrations: configuration.registrations, moduleName: configuration.moduleName)
            }
        }
    }

    static func resolverExtensions(
        registrations: [Registration],
        registrationsIntoCollections: [RegistrationIntoCollection]
    ) throws -> SourceFileSyntax {
        let withArguments = registrations.filter { !$0.arguments.isEmpty }

        return try SourceFileSyntax() {
            // swiftlint:disable line_length
            try ExtensionDeclSyntax("private extension Resolver") {
                // This assert is only needed if there are registrations without arguments
                if registrations.count > withArguments.count {
                    try makeTypeAssert()
                }

                // This assert is only needed if there are registrations with arguments
                if !withArguments.isEmpty {
                    try makeResultAssert()
                }

                if !groupByService(registrationsIntoCollections).isEmpty {
                    try makeCollectionAssert()
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

    static func makeAssertCall(registration: Registration) -> CodeBlockItemListSyntax {
        let expression = makeAssertCallExpression(registration: registration)
        let codeBlock = CodeBlockItemListSyntax([.init(item: .init(expression))])

        // Wrap the output in an #if where needed
        guard let ifConfigCondition = registration.ifConfigCondition else {
            return codeBlock
        }
        let clause = IfConfigClauseSyntax(
            poundKeyword: .poundIfToken(),
            condition: ifConfigCondition,
            elements: .statements(codeBlock)
        )
        let ifConfig = IfConfigDeclSyntax(clauses: [clause])
        return CodeBlockItemListSyntax([.init(item: .init(ifConfig))])
    }

    /// Generate a function call to test a single registration resolves
    private static func makeAssertCallExpression(registration: Registration) -> ExprSyntax {
        if !registration.arguments.isEmpty {
            let argParams = argumentParams(registration: registration)
            let nameParam = registration.name.map { "name: \"\($0)\""}
            let params = ["\(registration.service).self", nameParam, argParams].compactMap { $0 }.joined(separator: ", ")
            return "resolver.assertTypeResolved(resolver.resolve(\(raw: params)))"
        } else if let name = registration.name {
            return "resolver.assertTypeResolves(\(raw: registration.service).self, name: \"\(raw: name)\")"
        } else {
            return "resolver.assertTypeResolves(\(raw: registration.service).self)"
        }
    }

    private static func makeCollectionAssert() throws -> FunctionDeclSyntax {
        let string: SyntaxNodeString = #"""
        func assertCollectionResolves<T>(
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
        return try FunctionDeclSyntax(string)
    }

    /// Generate a function to assert that a type can be resolved
    private static func makeTypeAssert() throws -> FunctionDeclSyntax {
        let string: SyntaxNodeString = #"""
        func assertTypeResolves<T>(
            _ type: T.Type,
            name: String? = nil,
            file: StaticString = #filePath,
            line: UInt = #line
        ) {
            XCTAssertNotNil(
                resolve(type, name: name),
                """
                The container did not resolve the type: \(type). Check that this type is registered correctly.
                Dependency Graph:
                \(_dependencyTree())
                """,
                file: file,
                line: line
            )
        }
        """#
        return try FunctionDeclSyntax(string)
    }

    /// Generate a function to assert that a value resolved correctly
    private static func makeResultAssert() throws -> FunctionDeclSyntax {
        let string: SyntaxNodeString = #"""
        func assertTypeResolved<T>(
            _ result: T?,
            file: StaticString = #filePath,
            line: UInt = #line
        ) {
            XCTAssertNotNil(
                result,
                """
                The container did not resolve the type: \(T.self). Check that this type is registered correctly.
                Dependency Graph:
                \(_dependencyTree())
                """,
                file: file,
                line: line
            )
        }
        """#
        return try FunctionDeclSyntax(string)
    }

    /// Generate code for a struct that contains all of the parameters used to resolve services
    static func makeArgumentStruct(registrations: [Registration], moduleName: String) throws -> StructDeclSyntax {
        let fields = registrations.flatMap { $0.serviceNamedArguments() }
        var seen: Set<String> = []
        // Make sure duplicate parameters don't get created
        let uniqueFields = fields.filter {
            let key = "\($0.resolvedIdentifier())-\($0.type)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }

        return try StructDeclSyntax("struct \(raw: moduleName)RegistrationTestArguments") {
            for field in uniqueFields {
                DeclSyntax("let \(raw: field.resolvedIdentifier()): \(raw: field.type)")
            }
        }
    }

    private static func argumentParams(registration: Registration) -> String {
        if registration.arguments.isEmpty {
            fatalError("Should only be called for registrations with arguments")
        }
        let prefix = registration.arguments.count == 1 ? "argument:" : "arguments:"
        let params = registration.serviceNamedArguments().map { "args.\($0.resolvedIdentifier())" }.joined(separator: ", ")
        return "\(prefix) \(params)"
    }

}

private extension Registration {

    /// Argument names prefixed with the service name. Provides additional collision safety.
    func serviceNamedArguments() -> [Argument] {
        return namedArguments().map { arg in
            let serviceName = self.service.prefix(1).lowercased() + self.service.dropFirst()
            let capitalizedName = arg.resolvedIdentifier().prefix(1).uppercased() + arg.resolvedIdentifier().dropFirst()
            return Argument(identifier: serviceName + capitalizedName, type: arg.type)
        }
    }

}
