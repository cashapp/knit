// Copyright © Square, Inc. All rights reserved.

@testable import KnitCodeGen
import Foundation
import SwiftSyntax
import XCTest

final class TypeSafetySourceFileTests: XCTestCase {

    func test_generation() {
        let result = TypeSafetySourceFile.make(
            assemblyName: "ModuleAssembly",
            imports: [ImportDeclSyntax("import Swinject")],
            extensionTarget: "Resolve",
            registrations: [
                .init(service: "ServiceA", name: nil, accessLevel: .internal, isForwarded: false),
                .init(service: "ServiceB", name: "name", accessLevel: .internal, isForwarded: false),
                .init(service: "ServiceB", name: "otherName", accessLevel: .internal, isForwarded: false),
                .init(service: "ServiceC", name: nil, accessLevel: .hidden, isForwarded: false), // No resolver is created
                .init(service: "ServiceD", name: nil, accessLevel: .public, isForwarded: true, identifiedGetter: .both),
                .init(service: "ServiceE", name: nil, accessLevel: .public, arguments: [.init(type: "() -> Void")]),
                .init(service: "ServiceF", name: nil, accessLevel: .public, identifiedGetter: .identifiedGetterOnly),
            ]
        )

        let expected = """

        // Generated using Knit
        // Do not edit directly!

        import Swinject
        // The correct resolution of each of these types is enforced by a matching automated unit test
        // If a type registration is missing or broken then the automated tests will fail for that PR
        extension Resolve {
            func callAsFunction() -> ServiceA {
                self.resolve(ServiceA.self)!
            }
            public func callAsFunction() -> ServiceD {
                self.resolve(ServiceD.self)!
            }
            public func callAsFunction(closure: @escaping () -> Void) -> ServiceE {
                self.resolve(ServiceE.self, argument: closure)!
            }
            func callAsFunction(name: ModuleAssembly.ServiceB_ResolutionKey) -> ServiceB {
                self.resolve(ServiceB.self, name: name.rawValue)!
            }
            public func serviceD() -> ServiceD {
                self.resolve(ServiceD.self)!
            }
            public func serviceF() -> ServiceF {
                self.resolve(ServiceF.self)!
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
            TypeSafetySourceFile.makeResolver(
                registration: registration,
                enumName: nil
            ).formatted().description,
            """
            public func callAsFunction(string: String, url: URL) -> A {
                self.resolve(A.self, arguments: string, url)!
            }
            """
        )
    }

    func testRegistrationSingleArgument() {
        let registration = Registration(service: "A", accessLevel: .public, arguments: [.init(type: "String")])
        XCTAssertEqual(
            TypeSafetySourceFile.makeResolver(
                registration: registration,
                enumName: nil
            ).formatted().description,
            """
            public func callAsFunction(string: String) -> A {
                self.resolve(A.self, argument: string)!
            }
            """
        )
    }

    func testRegistrationDuplicateParamType() {
        let registration = Registration(service: "A", accessLevel: .public, arguments: [.init(type: "String"), .init(type: "String")])
        XCTAssertEqual(
            TypeSafetySourceFile.makeResolver(
                registration: registration,
                enumName: nil
            ).formatted().description,
            """
            public func callAsFunction(string1: String, string2: String) -> A {
                self.resolve(A.self, arguments: string1, string2)!
            }
            """
        )
    }

    func testRegistrationArgumentAndName() {
        let registration = Registration(service: "A", name: "test", accessLevel: .public, arguments: [.init(type: "String")])
        XCTAssertEqual(
            TypeSafetySourceFile.makeResolver(
                registration: registration,
                enumName: "MyAssembly.A_ResolutionKey"
            ).formatted().description,
            """
            public func callAsFunction(name: MyAssembly.A_ResolutionKey, string: String) -> A {
                self.resolve(A.self, name: name.rawValue, argument: string)!
            }
            """
        )
    }

    func testRegistrationWithPrenamedArguments() {
        let registration = Registration(service: "A", accessLevel: .public, arguments: [.init(identifier: "arg", type: "String")])
        XCTAssertEqual(
            TypeSafetySourceFile.makeResolver(
                registration: registration,
                enumName: nil
            ).formatted().description,
            """
            public func callAsFunction(arg: String) -> A {
                self.resolve(A.self, argument: arg)!
            }
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
