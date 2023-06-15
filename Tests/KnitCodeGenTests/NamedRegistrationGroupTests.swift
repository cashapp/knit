// Copyright © Square, Inc. All rights reserved.

@testable import KnitCodeGen
import Foundation
import XCTest

final class NamedRegistrationGroupTests: XCTestCase {

    func testRegistrationGrouping() throws {
        let registrations: [Registration] = [
            .init(service: "ServiceA", name: nil, accessLevel: .internal, isForwarded: false),
            .init(service: "ServiceA", name: "name1", accessLevel: .internal, isForwarded: false),
            .init(service: "ServiceB", name: "name1", accessLevel: .internal, isForwarded: false),
            .init(service: "ServiceA", name: "name2", accessLevel: .internal, isForwarded: false),
            .init(service: "ServiceB", name: "name3", accessLevel: .public, isForwarded: false),
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

}