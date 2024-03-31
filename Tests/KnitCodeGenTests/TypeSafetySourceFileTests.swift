//
// Copyright © Block, Inc. All rights reserved.
//

@testable import KnitCodeGen
import Foundation
import SwiftSyntax
import XCTest

final class TypeSafetySourceFileTests: XCTestCase {

    func test_generation() throws {
        let result = try TypeSafetySourceFile.make(
            assemblyName: "ModuleAssembly",
            extensionTarget: "Resolve",
            registrations: [
                .init(service: "ServiceA", name: nil),
                .init(service: "ServiceB", name: "name"),
                .init(service: "ServiceB", name: "otherName"),
                .init(service: "ServiceC", name: nil, accessLevel: .hidden), // No resolver is created
                .init(service: "ServiceD", name: nil, accessLevel: .public, getterConfig: GetterConfig.both, functionName: .implements),
                .init(service: "ServiceE", name: nil, accessLevel: .public, arguments: [.init(type: "() -> Void")]),
                .init(service: "ServiceF", name: nil, accessLevel: .public, getterConfig: [GetterConfig.identifiedGetter(nil)]),
                .init(service: "(String, Int?)", name: nil, accessLevel: .public, getterConfig: [GetterConfig.identifiedGetter(nil)]),
            ]
        )

        let expected = """
        // Generated from ModuleAssembly
        extension Resolve {
            func serviceA() -> ServiceA {
                knitUnwrap(resolve(ServiceA.self))
            }
            public func callAsFunction() -> ServiceD {
                knitUnwrap(resolve(ServiceD.self))
            }
            public func serviceD() -> ServiceD {
                knitUnwrap(resolve(ServiceD.self))
            }
            public func serviceE(closure: @escaping () -> Void) -> ServiceE {
                knitUnwrap(resolve(ServiceE.self, argument: closure))
            }
            public func serviceF() -> ServiceF {
                knitUnwrap(resolve(ServiceF.self))
            }
            public func stringInt() -> (String, Int?) {
                knitUnwrap(resolve((String, Int?).self))
            }
            func serviceB(name: ModuleAssembly.ServiceB_ResolutionKey) -> ServiceB {
                knitUnwrap(resolve(ServiceB.self, name: name.rawValue))
            }
        }
        extension ModuleAssembly {
            enum ServiceB_ResolutionKey: String, CaseIterable {
                case name
                case otherName
            }
        }
        """

        XCTAssertEqual(expected, result.formatted().description)
    }

    func testRegistrationMultipleArguments() {
        let registration = Registration(service: "A", accessLevel: .public, arguments: [.init(type: "String"), .init(type: "URL")])
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolver(
                registration: registration,
                enumName: nil
            ).formatted().description,
            """
            public func callAsFunction(string: String, url: URL) -> A {
                knitUnwrap(resolve(A.self, arguments: string, url))
            }
            """
        )
    }

    func testRegistrationSingleArgument() {
        let registration = Registration(service: "A", accessLevel: .public, arguments: [.init(type: "String")])
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolver(
                registration: registration,
                enumName: nil
            ).formatted().description,
            """
            public func callAsFunction(string: String) -> A {
                knitUnwrap(resolve(A.self, argument: string))
            }
            """
        )
    }

    func testRegistrationDuplicateParamType() {
        let registration = Registration(service: "A", accessLevel: .public, arguments: [.init(type: "String"), .init(type: "String")])
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolver(
                registration: registration,
                enumName: nil
            ).formatted().description,
            """
            public func callAsFunction(string1: String, string2: String) -> A {
                knitUnwrap(resolve(A.self, arguments: string1, string2))
            }
            """
        )
    }

    func testRegistrationArgumentAndName() {
        let registration = Registration(service: "A", name: "test", accessLevel: .public, arguments: [.init(type: "String")])
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolver(
                registration: registration,
                enumName: "MyAssembly.A_ResolutionKey"
            ).formatted().description,
            """
            public func callAsFunction(name: MyAssembly.A_ResolutionKey, string: String) -> A {
                knitUnwrap(resolve(A.self, name: name.rawValue, argument: string))
            }
            """
        )
    }

    func testRegistrationWithPrenamedArguments() {
        let registration = Registration(service: "A", accessLevel: .public, arguments: [.init(identifier: "arg", type: "String")])
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolver(
                registration: registration,
                enumName: nil
            ).formatted().description,
            """
            public func callAsFunction(arg: String) -> A {
                knitUnwrap(resolve(A.self, argument: arg))
            }
            """
        )
    }

    func testRegistrationWithIfConfig() {
        var registration = Registration(service: "A", accessLevel: .public)
        registration.ifConfigCondition = ExprSyntax("SOME_FLAG")
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolver(
                registration: registration,
                enumName: nil
            ).formatted().description,
            """
            #if SOME_FLAG
            public func callAsFunction() -> A {
                knitUnwrap(resolve(A.self))
            }
            #endif
            """
        )
    }

    func testArgumentNames() {
        let registration1 = Registration(service: "A", accessLevel: .public, arguments: [.init(type: "String?")])
        XCTAssertEqual(
            registration1.namedArguments().map { $0.resolvedIdentifier() },
            ["string"]
        )

        let registration2 = Registration(service: "A", accessLevel: .public, arguments: [.init(type: "Service.Argument")])
        XCTAssertEqual(
            registration2.namedArguments().map { $0.resolvedIdentifier() },
            ["argument"]
        )

        let registration3 = Registration(service: "A", accessLevel: .public, arguments: [.init(type: "Result<String, Error>")])
        XCTAssertEqual(
            registration3.namedArguments().map { $0.resolvedIdentifier() },
            ["result"]
        )

        let registration4 = Registration(
            service: "A",
            accessLevel: .public,
            arguments: [.init(type: "[Result<ServerResponse<Any>, Swift.Error>]")]
        )
        XCTAssertEqual(
            registration4.namedArguments().map { $0.resolvedIdentifier() },
            ["result"]
        )

    }

}
