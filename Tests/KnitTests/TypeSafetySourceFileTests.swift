// Copyright © Square, Inc. All rights reserved.

@testable import Knit
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
                .init(service: "ServiceA", name: nil, accessLevel: .internal),
                .init(service: "ServiceB", name: "name", accessLevel: .internal),
                .init(service: "ServiceB", name: "otherName", accessLevel: .internal),
                .init(service: "ServiceC", name: nil, accessLevel: .hidden), // No resolver is created
            ]
        )

        let expected = """

        // Generated using SwiftSyntax
        // Do not edit directly!

        //
        // Copyright © Square, Inc. All rights reserved.
        //
        import Swinject
        // The correct resolution of each of these types is enforced by a matching automated unit test
        // If a type registration is missing or broken then the automated tests will fail for that PR
        extension Resolve {
            func callAsFunction() -> ServiceA {
                self.resolve(ServiceA.self)!
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
