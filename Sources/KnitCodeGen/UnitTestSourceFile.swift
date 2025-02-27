//
// Copyright © Block, Inc. All rights reserved.
//

import SwiftSyntax
import SwiftSyntaxBuilder

public enum UnitTestSourceFile {

    public static func make(
        configuration: Configuration,
        testAssemblerClass: String,
        isAdditionalTest: Bool
    ) throws -> SourceFileSyntax {
        let withArguments = configuration.registrations.filter { !$0.arguments.isEmpty }
        let hasArguments = !withArguments.isEmpty

        let registrationToGenerate: [Registration]
        if isAdditionalTest {
            // Filter out registrations not supported for full testing
            registrationToGenerate = configuration.registrationsCompatibleWithCompleteTests
        } else {
            registrationToGenerate = configuration.registrations
        }

        return try SourceFileSyntax() {
            try ClassDeclSyntax("final class \(raw: configuration.assemblyShortName)RegistrationTests: XCTestCase") {

                try FunctionDeclSyntax("""
                    @MainActor
                    func testRegistrations()
                """) {

                    DeclSyntax("""
                        // In the test target for your module, please provide a static method that creates a
                        // ModuleAssembler instance for testing.
                        let assembler = \(raw: testAssemblerClass).makeAssemblerForTests()
                        """)

                    if hasArguments && !isAdditionalTest {
                        DeclSyntax("""
                            // In the test target for your module, please provide a static method that provides
                            // an instance of \(raw: configuration.assemblyShortName)RegistrationTestArguments
                            let args: \(raw: configuration.assemblyShortName)RegistrationTestArguments = \(raw: configuration.assemblyName).makeArgumentsForTests()
                            """)
                    }

                    if configuration.registrations.isEmpty && configuration.registrationsIntoCollections.isEmpty {
                        DeclSyntax("let _ = assembler.resolver")
                    } else {
                        DeclSyntax("let resolver = assembler.resolver")
                    }

                    for registration in registrationToGenerate {
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
                try makeArgumentStruct(registrations: configuration.registrations, assemblyName: configuration.assemblyShortName)
            }
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

    /// Generate code for a struct that contains all of the parameters used to resolve services
    static func makeArgumentStruct(registrations: [Registration], assemblyName: String) throws -> StructDeclSyntax {
        let fields = registrations.flatMap { $0.serviceIdentifiedArguments() }
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

        return try StructDeclSyntax("struct \(raw: assemblyName)RegistrationTestArguments") {
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
        let params = registration.serviceIdentifiedArguments().map { "args.\($0.resolvedIdentifier())" }.joined(separator: ", ")
        return "\(prefix) \(params)"
    }

}

private extension Registration {

    /// Argument identifiers prefixed with the service name. Provides additional collision safety.
    func serviceIdentifiedArguments() -> [Argument] {
        return uniquelyIdentifiedArguments().map { arg in
            let sanitizedServiceName = TypeNamer.sanitizeType(type: service, keepGenerics: true)
            let serviceName = sanitizedServiceName.prefix(1).lowercased() + sanitizedServiceName.dropFirst()
            let capitalizedName = arg.resolvedIdentifier().prefix(1).uppercased() + arg.resolvedIdentifier().dropFirst()
            // When generating the test arguments struct, the `@escaping` attribute should always be removed from the
            // argument type, as assigning a closure type to a property is inherently escaping
            // and will result in a compilation error.
            let type = arg.type.replacingOccurrences(of: "@escaping ", with: "")
            return Argument(identifier: serviceName + capitalizedName, type: type)
        }
    }

}
