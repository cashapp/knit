//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import XCTest

final class AbstractRegistrationTests: XCTestCase {

    func testMissingRegistration() {
        let container = Container()
        let abstractRegistrations = container.registerAbstractContainer()
        container.registerAbstract(String.self)
        container.registerAbstract(String.self, name: "test")

        XCTAssertThrowsError(try abstractRegistrations.validate()) { error in
            XCTAssertEqual(
                error.localizedDescription,
                """
                Unsatisfied abstract registration. Service: String, File: AbstractRegistrationTests.swift
                Unsatisfied abstract registration. Service: String, File: AbstractRegistrationTests.swift, Name: test
                """
            )
        }
    }

    func testFilledRegistrations() {
        let container = Container()
        let abstractRegistrations = container.registerAbstractContainer()
        container.registerAbstract(String.self)
        container.register(String.self) { _ in "Test" }
        XCTAssertNoThrow(try abstractRegistrations.validate())
        XCTAssertEqual(container.resolve(String.self), "Test")
    }

    func testNamedRegistrations() {
        let container = Container()
        let abstractRegistrations = container.registerAbstractContainer()
        container.registerAbstract(String.self)
        container.registerAbstract(String.self, name: "test")

        container.register(String.self) { _ in "Test" }
        XCTAssertThrowsError(try abstractRegistrations.validate())

        container.register(String.self, name: "wrong") { _ in "Test" }
        XCTAssertThrowsError(try abstractRegistrations.validate())

        container.register(String.self, name: "test") { _ in "Test" }
        XCTAssertNoThrow(try abstractRegistrations.validate())
    }

    func testPreRegistered() {
        let container = Container()
        let abstractRegistrations = container.registerAbstractContainer()
        container.register(String.self) { _ in "Test" }
        container.registerAbstract(String.self)
        XCTAssertNoThrow(try abstractRegistrations.validate())
    }

}
