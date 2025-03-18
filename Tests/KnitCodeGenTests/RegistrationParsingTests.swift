//
// Copyright © Block, Inc. All rights reserved.
//

@testable import KnitCodeGen
import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest

final class RegistrationParsingTests: XCTestCase {

    func testRegistrationStatements() throws {
        try assertRegistrationString(
            "container.register(AType.self)",
            serviceName: "AType"
        )
        try assertMultipleRegistrationsString(
            """
            container.register(AType.self) { _ in }
            .implements(AnotherType.self)
            .inObjectScope(.container)
            """,
            registrations: [
                Registration(service: "AType", name: nil, accessLevel: .internal, functionName: .register),
                Registration(service: "AnotherType", name: nil, accessLevel: .internal, functionName: .implements),
            ]
        )
        try assertRegistrationString(
            """
            container.register(
                AnyPublisher<DataState, Never>.self,
                factory: DataStateProvider.adapter
            )
            """,
            serviceName: "AnyPublisher<DataState, Never>"
        )
        try assertRegistrationString(
            """
            container.register(
                ((String) -> EntityGainLossDataArchiver).self,
                factory: FileClusterDataArchiver.makeArchiverProviderForEntityGainLoss
            )
            """,
            serviceName: "((String) -> EntityGainLossDataArchiver)"
        )

        try assertRegistrationString(
            """
            // @knit public
            container.register(AType.self)
            """,
            serviceName: "AType",
            accessLevel: .public
        )
    }

    func testHiddenRegistrations() throws {
        try assertRegistrationString(
            """
            // @knit hidden
            container.register(AType.self)
            """,
            serviceName: "AType",
            accessLevel: .hidden
        )
    }

    func testNamedRegistrations() throws {
        try assertRegistrationString(
            """
            container.register(A.self, name: "service") { }
            """,
            serviceName: "A",
            name: "service"
        )
    }

    func testGetterConfigRegistrations() throws {
        try assertMultipleRegistrationsString(
            """
            // @knit public alias("alias")
            container.register(A.self) { }
            """,
            registrations: [
                .init(service: "A", accessLevel: .public, getterAlias: "alias")
            ]
        )
    }

    func testAbstractRegistration() throws {
        try assertRegistrationString(
            """
            container.registerAbstract(AType.self)
            """,
            serviceName: "AType"
        )

        try assertRegistrationString(
            """
            container.registerAbstract(AType.self, name: "service")
            """,
            serviceName: "AType",
            name: "service"
        )

        try assertRegistrationString(
            """
            container.registerAbstract(AType.self, name: "service", concurrency: .MainActor)
            """,
            serviceName: "AType",
            name: "service",
            concurrencyModifier: "@MainActor"
        )

    }

    func testForwardedRegistration() throws {
        try assertMultipleRegistrationsString(
            """
            container.register(A.self) { }
            .implements(B.self)
            """,
            registrations: [
                Registration(service: "A", name: nil, accessLevel: .internal, functionName: .register),
                Registration(service: "B", name: nil, accessLevel: .internal, functionName: .implements),
            ]
        )

        try assertMultipleRegistrationsString(
            """
            container.register(A.self, factory: A.init)
            .implements(B.self)
            // @knit public
            .implements(C.self, name: "foo")
            .implements(D.self, name: "bar")
            """,
            registrations: [
                Registration(service: "A", name: nil, accessLevel: .internal, functionName: .register),
                Registration(service: "B", name: nil, accessLevel: .internal, functionName: .implements),
                Registration(service: "C", name: "foo", accessLevel: .public, functionName: .implements),
                Registration(service: "D", name: "bar", accessLevel: .internal, functionName: .implements),
            ]
        )

        try assertMultipleRegistrationsString(
            """
            // @knit hidden
            container.register(A.self) { }
            // @knit public
            .implements(B.self)
            // @knit hidden
            .implements(C.self)
            """,
            registrations: [
                Registration(service: "A", name: nil, accessLevel: .hidden, functionName: .register),
                Registration(service: "B", name: nil, accessLevel: .public, functionName: .implements),
                Registration(service: "C", name: nil, accessLevel: .hidden, functionName: .implements)
            ]
        )
    }

    func testRegisterWithArguments() throws {
        // Single argument, trailing closure
        try assertMultipleRegistrationsString(
            """
            container.register(A.self) { (_, arg: String) in
                A(string: arg)
            }
            """,
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: [.init(identifier: "arg", type: "String")])
            ]
        )

        // Single argument, named parameter
        try assertMultipleRegistrationsString(
            """
            container.register(A.self, factory: { (_, arg: String) in
                A(string: arg)
            })
            """,
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: [.init(identifier: "arg", type: "String")])
            ]
        )

        // Multiple arguments, trailing closure
        try assertMultipleRegistrationsString(
            """
            container.register(A.self) { (resolver: Resolver, arg: String, arg2: Int) in
                A()
            }
            """,
            registrations: [
                Registration(
                    service: "A",
                    accessLevel: .internal,
                    arguments: [
                        .init(identifier: "arg", type: "String"),
                        .init(identifier: "arg2", type: "Int"),
                    ]
                )
            ]
        )

        // Multiple arguments, named parameter
        try assertMultipleRegistrationsString(
            """
            container.register(A.self, factory: { (resolver: Resolver, arg: String, arg2: Int) in
                A()
            })
            """,
            registrations: [
                Registration(
                    service: "A",
                    accessLevel: .internal,
                    arguments: [
                        .init(identifier: "arg", type: "String"),
                        .init(identifier: "arg2", type: "Int"),
                    ]
                )
            ]
        )

        // Unused arguments (for test/abstract usages)
        try assertMultipleRegistrationsString(
            """
            container.register(A.self, factory: { (_: Resolver, _: String) in
                A()
            })
            """,
            registrations: [
                Registration(
                    service: "A",
                    accessLevel: .internal,
                    arguments: [
                        .init(identifier: nil, type: "String"),
                    ]
                )
            ]
        )
    }

    func testRegisterNonClosureFactoryType() throws {
        // This is acceptable syntax but we will not be able to parse any arguments
        try assertMultipleRegistrationsString(
            """
                container.register(A.self, factory: A.staticFunc)
            """,
            registrations: [
                Registration(service: "A", arguments: [])
            ]
        )
    }

    // Arguments on the main registration apply to implements also
    func testForwardedWithArgument() throws {
        // Single argument registration
        try assertMultipleRegistrationsString(
            """
            container.register(A.self) { (r: Resolver, url: URL) in 
                A(url: url)
            }
            .implements(B.self)
            """,
            registrations: [
                Registration(service: "A", arguments: [.init(identifier: "url", type: "URL")], functionName: .register),
                Registration(service: "B", arguments: [.init(identifier: "url", type: "URL")], functionName: .implements)
            ]
        )

        // Single argument register
        try assertMultipleRegistrationsString(
            """
            container.register(A.self) { (_, arg: String) in
                A(string: arg)
            }
            .implements(B.self)
            """,
            registrations: [
                Registration(service: "A", arguments: [.init(identifier: "arg", type: "String")]),
                Registration(service: "B", arguments: [.init(identifier: "arg", type: "String")], functionName: .implements)
            ]
        )
    }

    func testRegistrationWithComplexTypes() throws {
        try assertMultipleRegistrationsString(
            """
            container.register(A.self) { (_, arg: A.Argument) in
                A(string: arg.string)
            }
            """,
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: [.init(identifier: "arg", type: "A.Argument")]),
            ]
        )

        try assertMultipleRegistrationsString(
            """
            container.register(A.self) { (_, arg: Result<String?, Error>) in
                A(string: arg.string)
            }
            """,
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: [.init(identifier: "arg", type: "Result<String?, Error>")]),
            ]
        )
    }

    func testClosureArgument() throws {
        try assertMultipleRegistrationsString(
            """
            container.register(A.self) { (r: Resolver, closure: () -> Void) in
                A.init(closure: closure)
            }
            """,
            registrations: [
                Registration(
                    service: "A",
                    arguments: [.init(identifier: "closure", type: "() -> Void")],
                    functionName: .register
                ),
            ]
        )

        try assertMultipleRegistrationsString(
            """
            container.register(A.self) { (resolver, arg1: @escaping () -> Void) in
                A(arg: arg1)
            }
            """,
            registrations: [
                Registration(service: "A", arguments: [.init(identifier: "arg1", type: "@escaping () -> Void")]),
            ]
        )

        try assertMultipleRegistrationsString(
            """
            container.register(A.self) { (resolver, arg1: @escaping @MainActor @Sendable (Bool) -> Void) in
                A(arg: arg1)
            }
            """,
            registrations: [
                Registration(service: "A", arguments: [
                    .init(identifier: "arg1", type: "@escaping @MainActor @Sendable (Bool) -> Void")
                ]),
            ]
        )

        try assertMultipleRegistrationsString(
            """
            container.register(A.self) { (resolver, arg1: @escaping @CustomGlobalActor () -> Void) in
                A(arg: arg1)
            }
            """,
            registrations: [
                Registration(service: "A", arguments: [
                    .init(identifier: "arg1", type: "@escaping @CustomGlobalActor () -> Void")
                ]),
            ]
        )
    }

    func testArgumentMissingType() throws {
        // Type of arg can be inferred at build time but cannot be parsed
        let expr: ExprSyntax = """
            container.register(A.self) { (_, myArg) in
                A(string: myArg)
            }
        """

        let functionCall = try XCTUnwrap(FunctionCallExprSyntax(expr))

        XCTAssertThrowsError(try functionCall.getRegistrations()) { error in
            if case let RegistrationParsingError.missingArgumentType(_, name) = error {
                XCTAssertEqual(name, "myArg")
            } else {
                XCTFail("Incorrect error case")
            }
            XCTAssertEqual(
                error.localizedDescription,
                "Registration for myArg is missing a type. Type safe resolver has not been generated"
            )
        }
    }

    func testUnsupportedClosureSynatx() throws {
        let expr: ExprSyntax = """
            container.register(A.self) { _, myArg in
                A(string: myArg)
            }
        """

        let functionCall = try XCTUnwrap(FunctionCallExprSyntax(expr))

        XCTAssertThrowsError(try functionCall.getRegistrations()) { error in
            if case RegistrationParsingError.unwrappedClosureParams = error {
                // Correct error case
            } else {
                XCTFail("Incorrect error case")
            }
            XCTAssertEqual(
                error.localizedDescription,
                "Registrations must wrap argument closures and add types: e.g. { (resolver: Resolver, arg: MyArg) in"
            )
        }
    }

    func testInvalidName() throws {
        let expr: ExprSyntax = """
            container.register(A.self, name: name) { _ in
                A()
            }
        """

        let functionCall = try XCTUnwrap(FunctionCallExprSyntax(expr))

        XCTAssertThrowsError(try functionCall.getRegistrations()) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Service name must be a static string. Found: name: name"
            )
        }
    }

    func testRegistrationIntoCollection() throws {
        try assertMultipleRegistrationsString(
            """
            container.registerIntoCollection(AType.self) {}
                .inObjectScope(.container)
            """,
            registrationsIntoCollections: [
                .init(service: "AType"),
            ]
        )
    }

    func testMultiLineComments() throws {
        try assertMultipleRegistrationsString(
            """
            // General comment
            // @knit public
            container.register(AType.self) {}
                .inObjectScope(.container)
            """,
            registrations: [
                .init(service: "AType", accessLevel: .public),
            ]
        )
    }

    func testMainActorParsing() throws {
        // Basic registration
        try assertMultipleRegistrationsString(
            """
            container.register(A.self) { @MainActor in A() }
            .implements(B.self)
            """,
            registrations: [
                Registration(service: "A", concurrencyModifier: "@MainActor", functionName: .register),
                Registration(service: "B", concurrencyModifier: "@MainActor", functionName: .implements),
            ]
        )

        // With arguments (must use mainActorFactory syntax)
        try assertMultipleRegistrationsString(
            """
            container.register(
                A.self,
                mainActorFactory: { (resolver: Resolver, arg1: B, arg2: C) in
                    A(arg1: arg1, arg2: arg2)
                }
            )
            """,
            registrations: [
                Registration(
                    service: "A",
                    arguments: [.init(identifier: "arg1", type: "B"), .init(identifier: "arg2", type: "C")],
                    concurrencyModifier: "@MainActor",
                    functionName: .register
                ),
            ]
        )
    }

    func testSPIParsing() throws {
        try assertMultipleRegistrationsString(
            """
            // @knit @_spi(Testing)
            container.registerAbstract(MyType.self)
            """,
            registrations: [
                Registration(service: "MyType", functionName: .registerAbstract, spi: "Testing"),
            ]
        )
    }

    func testCustomTags() throws {
        try assertMultipleRegistrationsString(
            """
            // @knit @tag("Foo")
            container.registerAbstract(MyType.self)
            """,
            registrations: [
                Registration(service: "MyType", customTags: ["Foo"], functionName: .registerAbstract),
            ]
        )
    }

    func testIncorrectRegistrations() throws {
        try assertNoRegistrationsString("container.someOtherMethod(AType.self)", message: "Incorrect method name")
        try assertNoRegistrationsString("container.register(A)", message: "First param is not a metatype")
        try assertNoRegistrationsString("doThing()", message:"Unrelated function call")
        try assertNoRegistrationsString("container.implements(AType.self)", message: "Missing primary registration")
    }

}

/// Assert that a single registration exists within the string, and that the registration matches provided parameters.
private func assertRegistrationString(
    _ string: String,
    serviceName: String,
    accessLevel: AccessLevel = .internal,
    name: String? = nil,
    isForwarded: Bool = false,
    concurrencyModifier: String? = nil,
    file: StaticString = #filePath, line: UInt = #line
) throws {
    let functionCall = try XCTUnwrap(FunctionCallExprSyntax("\(raw: string)" as ExprSyntax))

    let (registrations, registrationsIntoCollecions) = try functionCall.getRegistrations()
    XCTAssertEqual(registrations.count, 1, file: file, line: line)
    XCTAssert(registrationsIntoCollecions.isEmpty, file: file, line: line)

    let registration = registrations.first
    XCTAssertNotNil(registration, file: file, line: line)
    XCTAssertEqual(registration?.service, serviceName, file: file, line: line)
    XCTAssertEqual(registration?.accessLevel, accessLevel, file: file, line: line)
    XCTAssertEqual(registration?.name, name, file: file, line: line)
    XCTAssertEqual(registration?.isForwarded, isForwarded, file: file, line: line)
    XCTAssertEqual(registration?.concurrencyModifier, concurrencyModifier, file: file, line: line)
}

/// Assert that multiple registrations exist within the string.
private func assertMultipleRegistrationsString(
    _ string: String,
    registrations: [Registration] = [],
    registrationsIntoCollections: [RegistrationIntoCollection] = [],
    file: StaticString = #filePath, line: UInt = #line
) throws {
    let functionCall = try XCTUnwrap(FunctionCallExprSyntax("\(raw: string)" as ExprSyntax))

    let (parsedRegistrations, parsedRegistrationsIntoCollections) = try functionCall.getRegistrations()
    XCTAssertEqual(parsedRegistrations.count, registrations.count, file: file, line: line)
    XCTAssertEqual(parsedRegistrations, registrations, file: file, line: line)

    XCTAssertEqual(parsedRegistrationsIntoCollections.count, registrationsIntoCollections.count, file: file, line: line)
    XCTAssertEqual(parsedRegistrationsIntoCollections, registrationsIntoCollections, file: file, line: line)
}

/// Assert that no registrations exist within the string.
private func assertNoRegistrationsString(
    _ string: String,
    message: String = "",
    file: StaticString = #filePath, line: UInt = #line
) throws {
    let functionCall = try XCTUnwrap(FunctionCallExprSyntax("\(raw: string)" as ExprSyntax))
    let (registrations, registrationsIntoCollections) = try functionCall.getRegistrations()
    XCTAssert(registrations.isEmpty, message, file: file, line: line)
    XCTAssert(registrationsIntoCollections.isEmpty, message, file: file, line: line)
}
