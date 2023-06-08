// Copyright © Square, Inc. All rights reserved.

@testable import KnitCodeGen
import Foundation
import SwiftSyntax
import XCTest

final class UnitTestSourceFileTests: XCTestCase {

    func test_generation() throws {
        let result = try UnitTestSourceFile.make(
            importDecls: [ImportDeclSyntax(DeclSyntax("import Swinject"))!],
            setupCodeBlock: nil,
            registrations: [
                .init(service: "ServiceA", name: nil, accessLevel: .internal),
                .init(service: "ServiceB", name: "name", accessLevel: .internal),
                .init(service: "ServiceB", name: "otherName", accessLevel: .internal),
                .init(service: "ServiceC", name: nil, accessLevel: .hidden),
            ]
        )

        //Remote trailing line spaces
        let formattedResult = result.formatted().description.replacingOccurrences(of: ", \n", with: ",\n")

        let expected = """
        // Generated using SwiftSyntax
        // Do not edit directly!

        //
        // Copyright © Square, Inc. All rights reserved.
        //
        import Swinject
        final class DIRegistrationTests: XCTestCase {
            func testRegistrations() {
                // In the test target for your module, please provide a static method that creates a
                // ModuleAssembler instance for testing.
                let assembler = makeAssemblerForTests()
                let resolver = assembler.resolver
                resolver.assertTypeResolves(ServiceA.self)
                resolver.assertTypeResolves(ServiceB.self, name: "name")
                resolver.assertTypeResolves(ServiceB.self, name: "otherName")
                resolver.assertTypeResolves(ServiceC.self)
            }
        }
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
        """

        XCTAssertEqual(formattedResult, expected)
    }
}
