//
// Copyright © Block, Inc. All rights reserved.
//

@testable import KnitCodeGen
import XCTest
import SwiftSyntax

final class NamedRegistrationGroupSourceTests: XCTestCase {

    func testResolutionKeyWithInternalMacro() throws {
        let registration1 = Registration(service: "ServiceB", name: "name", ifConfigCondition: ExprSyntax("DEBUG"))
        let registration2 = Registration(service: "ServiceB", name: "name2")
        let registration3 = Registration(service: "ServiceB", name: "name3", ifConfigCondition: ExprSyntax("DEBUG"))
        let group = NamedRegistrationGroup.make(from: [registration1, registration2, registration3])[0]
        let result = try group.enumSourceCode(assemblyName: "Assembly")

        let expected = """
        enum ServiceB_ResolutionKey: String, CaseIterable {
            #if DEBUG
            case name
            #endif
            case name2
            #if DEBUG
            case name3
            #endif
        }
        """

        XCTAssertEqual(expected, result.formatted().description)

    }

    func testResolutionKeyWithExternalMacro() throws {
        let registration1 = Registration(service: "ServiceB", name: "name2", ifConfigCondition: ExprSyntax("DEBUG"))
        let group = NamedRegistrationGroup.make(from: [registration1])[0]
        let result = try group.enumSourceCode(assemblyName: "Assembly")

        let expected = """
        #if DEBUG
        enum ServiceB_ResolutionKey: String, CaseIterable {
            case name2
        }
        #endif
        """

        XCTAssertEqual(expected, result.formatted().description)
    }
}
