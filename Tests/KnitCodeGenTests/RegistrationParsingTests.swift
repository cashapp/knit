//
// Copyright © Square, Inc. All rights reserved.
//

@testable import KnitCodeGen
import SwiftSyntaxBuilder
import XCTest

final class RegistrationParsingTests: XCTestCase {

    func testRegistrationStatements() {
        assertRegistrationString(
            "container.register(AType.self)",
            serviceName: "AType"
        )
        assertRegistrationString(
            "container.autoregister(BType.self)",
            serviceName: "BType"
        )
        assertMultipleRegistrationsString(
            """
            container.register(AType.self) { _ in }
            .implements(AnotherType.self)
            .inObjectScope(.container)
            """,
            registrations: [
                Registration(service: "AType", name: nil, accessLevel: .internal, isForwarded: false),
                Registration(service: "AnotherType", name: nil, accessLevel: .internal, isForwarded: true),
            ]
        )
        assertRegistrationString(
            """
            container.autoregister(
                AnyPublisher<DataState, Never>.self,
                initializer: DataStateProvider.adapter
            )
            """,
            serviceName: "AnyPublisher<DataState, Never>"
        )
        assertRegistrationString(
            """
            container.autoregister(
                ((String) -> EntityGainLossDataArchiver).self,
                initializer: FileClusterDataArchiver.makeArchiverProviderForEntityGainLoss
            )
            """,
            serviceName: "((String) -> EntityGainLossDataArchiver)"
        )

        assertRegistrationString(
            """
            // @knit public
            container.register(AType.self)
            """,
            serviceName: "AType",
            accessLevel: .public
        )
    }

    func testHiddenRegistrations() {
        assertRegistrationString(
            """
            // @knit hidden
            container.register(AType.self)
            """,
            serviceName: "AType",
            accessLevel: .hidden
        )
    }

    func testNamedRegistrations() throws {
        assertRegistrationString(
            """
            container.register(A.self, name: "service") { }
            """,
            serviceName: "A",
            name: "service"
        )

        assertRegistrationString(
            """
            container.autoregister(A.self, name: "service2", initializer: A.init)
            """,
            serviceName: "A",
            name: "service2"
        )
    }

    func testGetterConfigRegistrations() throws {
        assertMultipleRegistrationsString(
            """
            // @knit public getter-named
            container.register(A.self) { }
            """,
            registrations: [
                .init(service: "A", accessLevel: .public, getterConfig: [.identifiedGetter(nil)])
            ]
        )

        assertMultipleRegistrationsString(
            """
            // @knit public getter-callAsFunction
            container.register(A.self) { }
            """,
            registrations: [
                .init(service: "A", accessLevel: .public, getterConfig: [.callAsFunction])
            ]
        )

        assertMultipleRegistrationsString(
            """
            // @knit public getter-named getter-callAsFunction
            container.register(A.self) { }
            """,
            registrations: [
                .init(service: "A", accessLevel: .public, getterConfig: GetterConfig.both)
            ]
        )
    }

    func testAbstractRegistration() throws {
        assertRegistrationString(
            """
            container.registerAbstract(AType.self)
            """,
            serviceName: "AType"
        )

        assertRegistrationString(
            """
            container.registerAbstract(AType.self, name: "service")
            """,
            serviceName: "AType",
            name: "service"
        )
    }

    func testForwardedRegistration() throws {
        assertMultipleRegistrationsString(
            """
            container.register(A.self) { }
            .implements(B.self)
            """,
            registrations: [
                Registration(service: "A", name: nil, accessLevel: .internal, isForwarded: false),
                Registration(service: "B", name: nil, accessLevel: .internal, isForwarded: true),
            ]
        )

        assertMultipleRegistrationsString(
            """
            container.autoregister(A.self, initializer: A.init)
            .implements(B.self)
            // @knit public
            .implements(C.self, name: "foo")
            .implements(D.self, name: "bar")
            """,
            registrations: [
                Registration(service: "A", name: nil, accessLevel: .internal, isForwarded: false),
                Registration(service: "B", name: nil, accessLevel: .internal, isForwarded: true),
                Registration(service: "C", name: "foo", accessLevel: .public, isForwarded: true),
                Registration(service: "D", name: "bar", accessLevel: .internal, isForwarded: true),
            ]
        )

        assertMultipleRegistrationsString(
            """
            // @knit hidden
            container.register(A.self) { }
            // @knit public
            .implements(B.self)
            // @knit hidden
            .implements(C.self)
            """,
            registrations: [
                Registration(service: "A", name: nil, accessLevel: .hidden, isForwarded: false),
                Registration(service: "B", name: nil, accessLevel: .public, isForwarded: true),
                Registration(service: "C", name: nil, accessLevel: .hidden, isForwarded: true)
            ]
        )
    }

    func testRegisterWithArguments() {
        // Single argument, trailing closure
        assertMultipleRegistrationsString(
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
        assertMultipleRegistrationsString(
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
        assertMultipleRegistrationsString(
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
        assertMultipleRegistrationsString(
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
    }

    func testAutoregisterWithArguments() {
        // Single argument
        assertMultipleRegistrationsString(
            "container.autoregister(A.self, argument: URL.self, initializer: A.init)",
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: [.init(type: "URL")])
            ]
        )

        // Multiple arguments
        assertMultipleRegistrationsString(
            """
            container.autoregister(
                A.self,
                arguments: URL.self,
                Int.self,
                String.self,
                initializer: A.init
            )
            """,
            registrations: [
                Registration(
                    service: "A",
                    accessLevel: .internal,
                    arguments: [
                        .init(type: "URL"),
                        .init(type: "Int"),
                        .init(type: "String"),
                    ]
                )
            ]
        )

        // Single argument with name
        assertMultipleRegistrationsString(
            """
            container.autoregister(A.self, name: "test", argument: URL.self, initializer: A.init)
            """,
            registrations: [
                Registration(service: "A", name: "test", accessLevel: .internal, arguments: [.init(type: "URL")])
            ]
        )

        // Multiple arguments with name
        assertMultipleRegistrationsString(
            """
            container.autoregister(
                A.self,
                name: "test",
                arguments: URL.self,
                Int.self,
                initializer: A.init
            )
            """,
            registrations: [
                Registration(
                    service: "A",
                    name: "test",
                    accessLevel: .internal,
                    arguments: [.init(type: "URL"), .init(type: "Int")]
                )
            ]
        )
    }

    func testRegisterNonClosureFactoryType() {
        // This is acceptable syntax but we will not be able to parse any arguments
        assertMultipleRegistrationsString(
            """
                container.register(A.self, factory: A.staticFunc)
            """,
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: [], isForwarded: false)
            ]
        )
    }

    // Arguments on the main registration apply to implements also
    func testForwardedWithArgument() {
        // Single argument autoregister
        assertMultipleRegistrationsString(
            """
            container.autoregister(A.self, argument: URL.self, initializer: A.init)
            .implements(B.self)
            """,
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: [.init(type: "URL")]),
                Registration(service: "B", accessLevel: .internal, arguments: [.init(type: "URL")], isForwarded: true)
            ]
        )

        // Single argument register
        assertMultipleRegistrationsString(
            """
            container.register(A.self) { (_, arg: String) in
                A(string: arg)
            }
            .implements(B.self)
            """,
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: [.init(identifier: "arg", type: "String")]),
                Registration(service: "B", accessLevel: .internal, arguments: [.init(identifier: "arg", type: "String")], isForwarded: true)
            ]
        )
    }

    func testRegistrationWithComplexTypes() {
        assertMultipleRegistrationsString(
            """
            container.register(A.self) { (_, arg: A.Argument) in
                A(string: arg.string)
            }
            """,
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: [.init(identifier: "arg", type: "A.Argument")]),
            ]
        )

        assertMultipleRegistrationsString(
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

    func testAutoRegistrationWithComplexTypes() {
        assertMultipleRegistrationsString(
            """
            container.autoregister(A.self, argument: String?.self, initializer: A.init)
            """,
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: [.init(type: "String?")]),
            ]
        )

        assertMultipleRegistrationsString(
            """
            container.autoregister(A.self, arguments: Result<Int, Error>.self, Optional<Int>.self, initializer: A.init)
            """,
            registrations: [
                Registration(
                    service: "A",
                    accessLevel: .internal,
                    arguments: [
                        .init(type: "Result<Int, Error>"),
                        .init(type: "Optional<Int>"),
                    ]),
            ]
        )
    }

    func testClosureArgument() {
        assertMultipleRegistrationsString(
            "container.autoregister(A.self, argument: (() -> Void).self, initializer: A.init)",
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: [.init(type: "(() -> Void)")]),
            ]
        )

        assertMultipleRegistrationsString(
            """
            container.register(A.self) { (resolver, arg1: @escaping () -> Void) in
                A(arg: arg1)
            }
            """,
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: [.init(identifier: "arg1", type: "() -> Void")]),
            ]
        )
    }

    func testArgumentMissingType() {
        // Type of arg can be inferred at build time but cannot be parsed
        let string = """
            container.register(A.self) { (_, myArg) in
                A(string: myArg)
            }
        """

        let functionCall = FunctionCallExpr(stringLiteral: string)

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

    func testUnsupportedClosureSynatx() {
        let string = """
            container.register(A.self) { _, myArg in
                A(string: myArg)
            }
        """

        let functionCall = FunctionCallExpr(stringLiteral: string)

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

    func testInvalidName() {
        let string = """
            container.register(A.self, name: name) { _ in
                A()
            }
        """

        let functionCall = FunctionCallExpr(stringLiteral: string)

        XCTAssertThrowsError(try functionCall.getRegistrations()) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Service name must be a static string. Found: name: name"
            )
        }
    }

    func testRegistrationIntoCollection() {
        assertMultipleRegistrationsString(
            """
            container.registerIntoCollection(AType.self) {}
                .inObjectScope(.container)
            """,
            registrationsIntoCollections: [
                .init(service: "AType"),
            ]
        )
        assertMultipleRegistrationsString(
            """
            container.autoregisterIntoCollection(AType.self, initializer: AType.init)
                .inObjectScope(.container)
            """,
            registrationsIntoCollections: [
                .init(service: "AType"),
            ]
        )
    }

    func testIncorrectRegistrations() {
        assertNoRegistrationsString("container.someOtherMethod(AType.self)", message: "Incorrect method name")
        assertNoRegistrationsString("container.register(A)", message: "First param is not a metatype")
        assertNoRegistrationsString("doThing()", message:"Unrelated function call")
        assertNoRegistrationsString("container.implements(AType.self)", message: "Missing primary registration")
    }

}

/// Assert that a single registration exists within the string, and that the registration matches provided parameters.
private func assertRegistrationString(
    _ string: String,
    serviceName: String,
    accessLevel: AccessLevel = .internal,
    name: String? = nil,
    isForwarded: Bool = false,
    file: StaticString = #filePath, line: UInt = #line
) {
    let functionCall = FunctionCallExpr(stringLiteral: string)

    let (registrations, registrationsIntoCollecions) = try! functionCall.getRegistrations()
    XCTAssertEqual(registrations.count, 1, file: file, line: line)
    XCTAssert(registrationsIntoCollecions.isEmpty, file: file, line: line)

    let registration = registrations.first
    XCTAssertNotNil(registration, file: file, line: line)
    XCTAssertEqual(registration?.service, serviceName, file: file, line: line)
    XCTAssertEqual(registration?.accessLevel, accessLevel, file: file, line: line)
    XCTAssertEqual(registration?.name, name, file: file, line: line)
    XCTAssertEqual(registration?.isForwarded, isForwarded, file: file, line: line)
}

/// Assert that multiple registrations exist within the string.
private func assertMultipleRegistrationsString(
    _ string: String,
    registrations: [Registration] = [],
    registrationsIntoCollections: [RegistrationIntoCollection] = [],
    file: StaticString = #filePath, line: UInt = #line
) {
    let functionCall = FunctionCallExpr(stringLiteral: string)

    let (parsedRegistrations, parsedRegistrationsIntoCollections) = try! functionCall.getRegistrations()
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
) {
    let functionCall = FunctionCallExpr(stringLiteral: string)
    let (registrations, registrationsIntoCollections) = try! functionCall.getRegistrations()
    XCTAssert(registrations.isEmpty, message, file: file, line: line)
    XCTAssert(registrationsIntoCollections.isEmpty, message, file: file, line: line)
}
