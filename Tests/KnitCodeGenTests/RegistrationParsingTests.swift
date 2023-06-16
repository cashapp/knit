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
        // Single argument
        assertMultipleRegistrationsString(
            """
            container.register(A.self) { (_, arg: String) in
                A(string: arg)
            }
            """,
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: ["String"])
            ]
        )

        // Multiple arguments
        assertMultipleRegistrationsString(
            """
            container.register(A.self) { (resolver: Resolver, arg: String, arg2: Int) in
                A()
            }
            """,
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: ["String", "Int"])
            ]
        )
    }

    func testAutoregisterWithArguments() {
        // Single argument
        assertMultipleRegistrationsString(
            "container.autoregister(A.self, argument: URL.self, initializer: A.init)",
            registrations: [
                Registration(service: "A", accessLevel: .internal, arguments: ["URL"])
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
                    arguments: ["URL", "Int", "String"]
                )
            ]
        )

        // Single argument with name
        assertMultipleRegistrationsString(
            """
            container.autoregister(A.self, name: "test", argument: URL.self, initializer: A.init)
            """,
            registrations: [
                Registration(service: "A", name: "test", accessLevel: .internal, arguments: ["URL"])
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
                    arguments: ["URL", "Int"]
                )
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
                Registration(service: "A", accessLevel: .internal, arguments: ["URL"]),
                Registration(service: "B", accessLevel: .internal, arguments: ["URL"], isForwarded: true)
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
                Registration(service: "A", accessLevel: .internal, arguments: ["String"]),
                Registration(service: "B", accessLevel: .internal, arguments: ["String"], isForwarded: true)
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
            XCTAssertEqual(
                error.localizedDescription,
                "Registration for myArg is missing a type. Type safe resolver has not been generated"
            )
        }
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

    let registrations = try! functionCall.getRegistrations()
    XCTAssertEqual(registrations.count, 1, file: file, line: line)

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
    registrations: [Registration],
    file: StaticString = #filePath, line: UInt = #line
) {
    let functionCall = FunctionCallExpr(stringLiteral: string)

    let parsedRegistrations = try! functionCall.getRegistrations()
    XCTAssertEqual(parsedRegistrations.count, registrations.count, file: file, line: line)
    XCTAssertEqual(parsedRegistrations, registrations, file: file, line: line)
}

/// Assert that no registrations exist within the string.
private func assertNoRegistrationsString(
    _ string: String,
    message: String = "",
    file: StaticString = #filePath, line: UInt = #line
) {
    let functionCall = FunctionCallExpr(stringLiteral: string)
    let registrations = try! functionCall.getRegistrations()
    XCTAssertEqual(registrations.count, 0, message, file: file, line: line)
}
