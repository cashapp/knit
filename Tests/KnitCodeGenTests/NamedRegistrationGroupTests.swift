//
// Copyright © Block, Inc. All rights reserved.
//

@testable import KnitCodeGen
import Foundation
import SwiftSyntax
import XCTest

final class NamedRegistrationGroupTests: XCTestCase {

    func testRegistrationGrouping() throws {
        let registrations: [Registration] = [
            .init(service: "ServiceA", name: nil),
            .init(service: "ServiceA", name: "name1"),
            .init(service: "ServiceB", name: "name1"),
            .init(service: "ServiceA", name: "name2"),
            .init(service: "ServiceB", name: "name3", accessLevel: .public),
        ]

        let namedGroups = NamedRegistrationGroup.make(from: registrations)
        XCTAssertEqual(namedGroups.count, 2)

        let serviceAGroup = try XCTUnwrap(namedGroups.first { $0.service == "ServiceA" })
        XCTAssertEqual(serviceAGroup.service, "ServiceA")
        XCTAssertEqual(serviceAGroup.registrations.count, 2)
        XCTAssertEqual(serviceAGroup.accessLevel, .internal)

        let serviceBGroup = try XCTUnwrap(namedGroups.first { $0.service == "ServiceB"})
        XCTAssertEqual(serviceBGroup.accessLevel, .public)

    }

    func testComplexEnumNaming() throws {
        let registrations: [Registration] = [
            .init(service: "AnyProfileValueProvider<BalanceSnapshot?>", name: "name1", accessLevel: .internal)
        ]

        let namedGroup = NamedRegistrationGroup.make(from: registrations)[0]

        XCTAssertEqual(
            namedGroup.enumName,
            "AnyProfileValueProvider_BalanceSnapshot_ResolutionKey"
        )
    }

    func testIfConfigCondition() throws {
        let registration1 = Registration(service: "ServiceA", name: "name1", ifConfigCondition: ExprSyntax("DEBUG"))
        let registration2 = Registration(service: "ServiceA", name: "name2")
        let registration3 = Registration(service: "ServiceA", name: "name3", ifConfigCondition: ExprSyntax("RELEASE"))

        let namedGroup1 = NamedRegistrationGroup.make(from: [registration1])[0]
        XCTAssertEqual(namedGroup1.ifConfigCondition?.description, ExprSyntax("DEBUG").description)

        let namedGroup2 = NamedRegistrationGroup.make(from: [registration1, registration2])[0]
        XCTAssertNil(namedGroup2.ifConfigCondition)

        let namedGroup3 = NamedRegistrationGroup.make(from: [registration1, registration3])[0]
        XCTAssertNil(namedGroup3.ifConfigCondition)
    }

}
