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
                .init(service: "ServiceD", accessLevel: .hidden, arguments: [.init(type: "String")]),
            ]
        )

        //Remote trailing line spaces
        let formattedResult = result.formatted().description.replacingOccurrences(of: ", \n", with: ",\n")

        let expected = """

        // Generated using Knit
        // Do not edit directly!

        import Swinject
        final class KnitDIRegistrationTests: XCTestCase {
            func testRegistrations() {
                // In the test target for your module, please provide a static method that creates a
                // ModuleAssembler instance for testing.
                let assembler = makeAssemblerForTests()
                // In the test target for your module, please provide a static method that provides
                // an instance of KnitRegistrationTestArguments
                let args: KnitRegistrationTestArguments = makeArgumentsForTests()
                let resolver = assembler.resolver
                resolver.assertTypeResolves(ServiceA.self)
                resolver.assertTypeResolves(ServiceB.self, name: "name")
                resolver.assertTypeResolves(ServiceB.self, name: "otherName")
                resolver.assertTypeResolves(ServiceC.self)
                resolver.assertTypeResolved(resolver.resolve(ServiceD.self, argument: args.serviceDString))
            }
        }
        struct KnitRegistrationTestArguments {
            let serviceDString: String
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
            func assertTypeResolved < T > (
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
        }
        """

        XCTAssertEqual(formattedResult, expected)
    }

    func test_argumentStruct() {
        let result = UnitTestSourceFile.makeArgumentStruct(registrations: [
            Registration(service: "A", accessLevel: .public, arguments: [.init(type: "String")]),
            Registration(service: "B", accessLevel: .public, arguments: [.init(name: "field", type: "String"), .init(type: "String")]),
            Registration(service: "A", accessLevel: .public, arguments: [.init(type: "Int"), .init(type: "String")]),
        ])

        let formattedResult = result.formatted().description.replacingOccurrences(of: ", \n", with: ",\n")

        let expected = """
        struct KnitRegistrationTestArguments {
            let aString: String
            let bField: String
            let bString: String
            let aInt: Int
        }
        """

        XCTAssertEqual(formattedResult, expected)
    }

    func test_registrationAssertPlain() {
        let result = UnitTestSourceFile.makeAssertCall(registration: .init(service: "A", accessLevel: .hidden))
        let formattedResult = result.formatted().description.replacingOccurrences(of: ", \n", with: ",\n")
        let expected = "resolver.assertTypeResolves(A.self)"
        XCTAssertEqual(formattedResult, expected)
    }

    func test_registrationAssertNamed() {
        let result = UnitTestSourceFile.makeAssertCall(registration: .init(service: "A", name: "Name", accessLevel: .hidden))
        let formattedResult = result.formatted().description.replacingOccurrences(of: ", \n", with: ",\n")
        let expected = "resolver.assertTypeResolves(A.self, name: \"Name\")"
        XCTAssertEqual(formattedResult, expected)
    }

    func test_registrationAssertArgument() {
        let registration = Registration(
            service: "A",
            name: "Name",
            accessLevel: .hidden,
            arguments: [
                .init(type: "String")
            ]
        )
        let result = UnitTestSourceFile.makeAssertCall(registration: registration)
        let formattedResult = result.formatted().description.replacingOccurrences(of: ", \n", with: ",\n")
        let expected = "resolver.assertTypeResolved(resolver.resolve(A.self, name: \"Name\", argument: args.aString))"
        XCTAssertEqual(formattedResult, expected)
    }

    func test_registrationAssertMultipleArguments() {
        let registration = Registration(
            service: "A",
            accessLevel: .hidden,
            arguments: [
                .init(type: "String"),
                .init(type: "String"),
            ]
        )
        let result = UnitTestSourceFile.makeAssertCall(registration: registration)
        let formattedResult = result.formatted().description.replacingOccurrences(of: ", \n", with: ",\n")
        let expected = "resolver.assertTypeResolved(resolver.resolve(A.self, arguments: args.aString1, args.aString2))"
        XCTAssertEqual(formattedResult, expected)
    }
}
