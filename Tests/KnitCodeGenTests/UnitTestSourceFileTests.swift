// Copyright © Square, Inc. All rights reserved.

@testable import KnitCodeGen
import Foundation
import SwiftSyntax
import XCTest

final class UnitTestSourceFileTests: XCTestCase {

    func test_generation() {
        let result = UnitTestSourceFile.make(
            importDecls: [ImportDeclSyntax("import Swinject")],
            setupCodeBlock: nil,
            registrations: [
                .init(service: "ServiceA", name: nil, accessLevel: .internal, isForwarded: false),
                .init(service: "ServiceB", name: "name", accessLevel: .internal, isForwarded: false),
                .init(service: "ServiceB", name: "otherName", accessLevel: .internal, isForwarded: true),
                .init(service: "ServiceC", name: nil, accessLevel: .hidden, isForwarded: false),
                // TODO: Generate test for types with arguments
                .init(service: "ServiceD", accessLevel: .hidden, arguments: [.init(type: "String")]),
            ],
            registrationsIntoCollections: [
                .init(service: "ServiceD"),
                .init(service: "ServiceD"),
            ]
        )

        //Remote trailing line spaces
        let formattedResult = result.formatted().description.replacingOccurrences(of: ", \n", with: ",\n")

        let expected = #"""

        // Generated using Knit
        // Do not edit directly!

        import Swinject
        final class KnitDIRegistrationTests: XCTestCase {
            func testRegistrations() {
                // In the test target for your module, please provide a static method that creates a
                // ModuleAssembler instance for testing.
                let assembler = makeAssemblerForTests()
                let resolver = assembler.resolver
                resolver.assertTypeResolves(ServiceA.self)
                resolver.assertTypeResolves(ServiceB.self, name: "name")
                resolver.assertTypeResolves(ServiceB.self, name: "otherName")
                resolver.assertTypeResolves(ServiceC.self)
                resolver.assertCollectionResolves(ServiceD.self, count: 2)
            }
        }
        private extension Resolver {

            func assertTypeResolves < T > (
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

            func assertCollectionResolves < T > (
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
        """#

        XCTAssertEqual(formattedResult, expected)
    }
}
