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
                .init(service: "ServiceD", name: nil, accessLevel: .public, isForwarded: true),
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
            func callAsFunction(named: ModuleAssembly.ServiceB_ResolutionKey) -> ServiceB {
                self.resolve(ServiceB.self, name: named.rawValue)!
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

}
