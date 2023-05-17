//
// Copyright © Square, Inc. All rights reserved.
//

@testable import Knit
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
        assertRegistrationString(
            """
            container.register(AType.self) { _ in }
            .implements(AnotherType.self)
            .inObjectScope(.container)
            """,
            serviceName: "AType"
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
            // @digen public
            container.register(AType.self)
            """,
            serviceName: "AType",
            accessLevel: .public
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

    func testIncorrectRegistrations() {
        assertNoRegistrationString("container.someOtherMethod(AType.self)", message: "Incorrect method name")
        assertNoRegistrationString("container.register(A)", message: "First param is not a metatype")
    }

}

private func assertRegistrationString(
    _ string: String,
    serviceName: String,
    accessLevel: AccessLevel = .internal,
    name: String? = nil,
    file: StaticString = #filePath, line: UInt = #line
) {
    let functionCall = FunctionCallExpr(stringLiteral: string)
    let registration = functionCall.getRegistration()
    XCTAssertNotNil(registration, file: file, line: line)
    XCTAssertEqual(registration?.service, serviceName, file: file, line: line)
    XCTAssertEqual(registration?.accessLevel, accessLevel, file: file, line: line)
    XCTAssertEqual(registration?.name, name, file: file, line: line)
}

private func assertNoRegistrationString(
    _ string: String,
    message: String = "",
    file: StaticString = #filePath, line: UInt = #line
) {
    let functionCall = FunctionCallExpr(stringLiteral: string)
    let registration = functionCall.getRegistration()
    XCTAssertNil(registration, message, file: file, line: line)
}
