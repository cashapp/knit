// Copyright © Square, Inc. All rights reserved.

@testable import KnitCodeGen
import Foundation
import SwiftSyntax
import XCTest

final class UnitTestSourceFileTests: XCTestCase {

    func test_generation() throws {
        let result = try UnitTestSourceFile.make(
            name: "MyModule",
            importDecls: [.named("Swinject")],
            registrations: [
                .init(service: "ServiceA", name: nil, accessLevel: .internal, isForwarded: false),
                .init(service: "ServiceB", name: "name", accessLevel: .internal, isForwarded: false),
                .init(service: "ServiceB", name: "otherName", accessLevel: .internal, isForwarded: true),
                .init(service: "ServiceC", name: nil, accessLevel: .hidden, isForwarded: false),
                .init(service: "ServiceD", accessLevel: .hidden, arguments: [.init(type: "String")]),
            ],
            registrationsIntoCollections: [
                .init(service: "ServiceD"),
                .init(service: "ServiceD"),
            ]
        )

        //Remote trailing line spaces
        let formattedResult = result.formatted().description

        let expected = #"""
        final class MyModuleRegistrationTests: XCTestCase {
            func testRegistrations() {
                // In the test target for your module, please provide a static method that creates a
                // ModuleAssembler instance for testing.
                let assembler = MyModuleAssembly.makeAssemblerForTests()
                // In the test target for your module, please provide a static method that provides
                // an instance of MyModuleRegistrationTestArguments
                let args: MyModuleRegistrationTestArguments = MyModuleAssembly.makeArgumentsForTests()
                let resolver = assembler.resolver
                resolver.assertTypeResolves(ServiceA.self)
                resolver.assertTypeResolves(ServiceB.self, name: "name")
                resolver.assertTypeResolves(ServiceB.self, name: "otherName")
                resolver.assertTypeResolves(ServiceC.self)
                resolver.assertTypeResolved(resolver.resolve(ServiceD.self, argument: args.serviceDString))
                resolver.assertCollectionResolves(ServiceD.self, count: 2)
            }
        }
        struct MyModuleRegistrationTestArguments {
            let serviceDString: String
        }
        """#

        XCTAssertEqual(formattedResult, expected)
    }

    func test_generation_emptyRegistrations() throws {
        let result = try UnitTestSourceFile.make(
            name: "MyModule",
            importDecls: [.named("Swinject")],
            registrations: [],
            registrationsIntoCollections: []
        )

        //Remote trailing line spaces
        let formattedResult = result.formatted().description

        let expected = #"""
        final class MyModuleRegistrationTests: XCTestCase {
            func testRegistrations() {
                // In the test target for your module, please provide a static method that creates a
                // ModuleAssembler instance for testing.
                let assembler = MyModuleAssembly.makeAssemblerForTests()
                let _ = assembler.resolver
            }
        }
        """#

        XCTAssertEqual(formattedResult, expected)
    }

    func test_generation_onlySingleRegistrations() throws {
        let result = try UnitTestSourceFile.make(
            name: "MyModule",
            importDecls: [.named("Swinject")],
            registrations: [
                .init(service: "ServiceA", name: nil, accessLevel: .internal, isForwarded: false),
            ],
            registrationsIntoCollections: []
        )

        //Remote trailing line spaces
        let formattedResult = result.formatted().description

        let expected = #"""
        final class MyModuleRegistrationTests: XCTestCase {
            func testRegistrations() {
                // In the test target for your module, please provide a static method that creates a
                // ModuleAssembler instance for testing.
                let assembler = MyModuleAssembly.makeAssemblerForTests()
                let resolver = assembler.resolver
                resolver.assertTypeResolves(ServiceA.self)
            }
        }
        """#

        XCTAssertEqual(formattedResult, expected)
    }

    func test_generation_onlyRegistrationsIntoCollections() throws {
        let result = try UnitTestSourceFile.make(
            name: "MyModule",
            importDecls: [.named("Swinject")],
            registrations: [],
            registrationsIntoCollections: [
                .init(service: "ServiceA"),
            ]
        )

        //Remote trailing line spaces
        let formattedResult = result.formatted().description

        let expected = #"""
        final class MyModuleRegistrationTests: XCTestCase {
            func testRegistrations() {
                // In the test target for your module, please provide a static method that creates a
                // ModuleAssembler instance for testing.
                let assembler = MyModuleAssembly.makeAssemblerForTests()
                let resolver = assembler.resolver
                resolver.assertCollectionResolves(ServiceA.self, count: 1)
            }
        }
        """#

        XCTAssertEqual(formattedResult, expected)
    }

    func test_argumentStruct() throws {
        let registrations = [
            Registration(service: "A", accessLevel: .public, arguments: [.init(type: "String")]),
            Registration(service: "B", accessLevel: .public, arguments: [.init(identifier: "field", type: "String"), .init(type: "String")]),
            Registration(service: "A", accessLevel: .public, arguments: [.init(type: "Int"), .init(type: "String")]),
        ]
        let result = try UnitTestSourceFile.makeArgumentStruct(registrations: registrations, moduleName: "MyModule")

        let formattedResult = result.formatted().description

        let expected = """
        struct MyModuleRegistrationTestArguments {
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
        let formattedResult = result.formatted().description
        let expected = "resolver.assertTypeResolves(A.self)"
        XCTAssertEqual(formattedResult, expected)
    }

    func test_registrationAssertNamed() {
        let result = UnitTestSourceFile.makeAssertCall(registration: .init(service: "A", name: "Name", accessLevel: .hidden))
        let formattedResult = result.formatted().description
        let expected = "resolver.assertTypeResolves(A.self, name: \"Name\")"
        XCTAssertEqual(formattedResult, expected)
    }

    func test_registrationAssertIfConfig() {
        var registration = Registration(service: "A", accessLevel: .hidden)
        registration.ifConfigCondition = ExprSyntax("SOME_FLAG && !DEBUG")
        let result = UnitTestSourceFile.makeAssertCall(registration: registration)
        let formattedResult = result.formatted().description
        XCTAssertEqual(
            formattedResult,
            """
            #if SOME_FLAG && !DEBUG
            resolver.assertTypeResolves(A.self)
            #endif
            """
        )
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
        let formattedResult = result.formatted().description
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
        let formattedResult = result.formatted().description
        let expected = "resolver.assertTypeResolved(resolver.resolve(A.self, arguments: args.aString1, args.aString2))"
        XCTAssertEqual(formattedResult, expected)
    }
}

private extension UnitTestSourceFile {

    static func make(
        name: String,
        importDecls: [ModuleImport],
        registrations: [Registration],
        registrationsIntoCollections: [RegistrationIntoCollection]
    ) throws -> SourceFileSyntax {
        let configuration = Configuration(
            name: name,
            registrations: registrations,
            registrationsIntoCollections: registrationsIntoCollections,
            imports: importDecls,
            targetResolver: "Resolver"
        )
        return try UnitTestSourceFile.make(configuration: configuration)
    }
}
