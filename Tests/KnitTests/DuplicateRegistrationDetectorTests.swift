//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import Swinject
import XCTest

final class DuplicateRegistrationDetectorTests: XCTestCase {

    func testBasicDetection() throws {
        var reportedDuplicates = [DuplicateRegistrationDetector.Key]()
        let duplicateRegistrationDetector = DuplicateRegistrationDetector(duplicateWasDetected: { key in
            reportedDuplicates.append(key)
        })
        let container = SwinjectContainer(
            behaviors: [duplicateRegistrationDetector]
        )

        XCTAssertEqual(reportedDuplicates.count, 0)
        container.register(String.self, factory: { _ in "one" })
        XCTAssertEqual(reportedDuplicates.count, 0)

        container.register(String.self, factory: { _ in "two" })
        XCTAssertEqual(reportedDuplicates.count, 1)
        let firstReport = try XCTUnwrap(reportedDuplicates.first)
        XCTAssert(firstReport.serviceType == String.self)
        XCTAssert(firstReport.argumentsType == (SwinjectResolver).self)
        XCTAssertEqual(firstReport.name, nil)

        container.register(String.self, factory: { _ in "three" })
        XCTAssertEqual(reportedDuplicates.count, 2)
    }

    func testNames() throws {
        var reportedDuplicates = [DuplicateRegistrationDetector.Key]()
        let duplicateRegistrationDetector = DuplicateRegistrationDetector(duplicateWasDetected: { key in
            reportedDuplicates.append(key)
        })
        let container = SwinjectContainer(
            behaviors: [duplicateRegistrationDetector]
        )

        XCTAssertEqual(reportedDuplicates.count, 0)
        container.register(String.self, factory: { _ in "no name" })
        container.register(String.self, name: "nameOne", factory: { _ in "one" })
        container.register(String.self, name: "nameTwo", factory: { _ in "two" })
        XCTAssertEqual(reportedDuplicates.count, 0)

        container.register(String.self, name: "nameOne", factory: { _ in "one duplicate" })
        XCTAssertEqual(reportedDuplicates.count, 1)
        let firstReport = try XCTUnwrap(reportedDuplicates.first)
        XCTAssert(firstReport.serviceType == String.self)
        XCTAssert(firstReport.argumentsType == (SwinjectResolver).self)
        XCTAssertEqual(firstReport.name, "nameOne")
    }

    func testArguments() throws {
        var reportedDuplicates = [DuplicateRegistrationDetector.Key]()
        let duplicateRegistrationDetector = DuplicateRegistrationDetector(duplicateWasDetected: { key in
            reportedDuplicates.append(key)
        })
        let container = SwinjectContainer(
            behaviors: [duplicateRegistrationDetector]
        )

        XCTAssertEqual(reportedDuplicates.count, 0)
        container.register(String.self, factory: { _ in "no arguments" })
        container.register(String.self, factory: { (_, _: Bool) in "Bool arg" })
        container.register(String.self, factory: { (_, _: Int) in "Int arg" })
        XCTAssertEqual(reportedDuplicates.count, 0)

        container.register(String.self, factory: { (_, _: Int) in "Int arg duplicate" })
        XCTAssertEqual(reportedDuplicates.count, 1)
        let firstReport = try XCTUnwrap(reportedDuplicates.first)
        XCTAssert(firstReport.serviceType == String.self)
        XCTAssert(firstReport.argumentsType == (SwinjectResolver, Int).self)
        XCTAssertEqual(firstReport.name, nil)
    }

    func testNoDuplicates() throws {
        var reportedDuplicates = [DuplicateRegistrationDetector.Key]()
        let duplicateRegistrationDetector = DuplicateRegistrationDetector(duplicateWasDetected: { key in
            reportedDuplicates.append(key)
        })
        let container = SwinjectContainer(
            behaviors: [duplicateRegistrationDetector]
        )

        container.register(String.self, factory: { _ in "" })
        container.register(Bool.self, factory: { _ in true })
        container.register(Int.self, factory: { _ in 1 })
        XCTAssertEqual(reportedDuplicates.count, 0)
    }

    func testParentContainerNotDuplicate() throws {
        // A parent container is allowed to contain the same registration key as a child container
        // This is not a duplicate but a "shadow" registration

        var reportedDuplicates = [DuplicateRegistrationDetector.Key]()

        let parentDuplicateRegistrationDetector = DuplicateRegistrationDetector(duplicateWasDetected: { key in
            reportedDuplicates.append(key)
        })
        let parentContainer = SwinjectContainer(behaviors: [parentDuplicateRegistrationDetector])

        let childDuplicateRegistrationDetector = DuplicateRegistrationDetector(duplicateWasDetected: { key in
            reportedDuplicates.append(key)
        })
        let childContainer = SwinjectContainer(parent: parentContainer, behaviors: [childDuplicateRegistrationDetector])

        parentContainer.register(String.self, factory: { _ in "parent" })
        childContainer.register(String.self, factory: { _ in "child" })

        XCTAssertEqual(reportedDuplicates.count, 0)
    }

    func testTypeForwarding() throws {
        // A forwarded type (`.implements()`) should not cause a duplicate registration
        let duplicateRegistrationDetector = DuplicateRegistrationDetector()
        let container = SwinjectContainer(behaviors: [duplicateRegistrationDetector])

        XCTAssertEqual(duplicateRegistrationDetector.detectedKeys.count, 0)
        container.register(String.self, factory: { _ in "string"} )
            .implements((any StringProtocol).self)
        XCTAssertEqual(duplicateRegistrationDetector.detectedKeys.count, 0)

        // Registering `Substring` does not cause a duplicate
        let substringEntry = container.register(Substring.self, factory: { _ in "substring"} )
        XCTAssertEqual(duplicateRegistrationDetector.detectedKeys.count, 0)
        // However forwarding to the same type twice still results in a duplicate
        substringEntry.implements((any StringProtocol).self)
        XCTAssertEqual(duplicateRegistrationDetector.detectedKeys.count, 1)
    }

    func testIgnoredServices() throws {
        var reportedDuplicates = [DuplicateRegistrationDetector.Key]()
        let duplicateRegistrationDetector = DuplicateRegistrationDetector(
            ignoredServices: [
                String.self,
            ]
        ) {
            reportedDuplicates.append($0)
        }
        let container = SwinjectContainer(
            behaviors: [duplicateRegistrationDetector]
        )

        container.register(String.self, factory: { _ in "one" })
        container.register(Int.self, factory: { _ in 1 })
        XCTAssertEqual(reportedDuplicates.count, 0)

        container.register(String.self, factory: { _ in "two" })
        XCTAssertEqual(reportedDuplicates.count, 0)
        container.register(Int.self, factory: { _ in 2 })
        XCTAssertEqual(reportedDuplicates.count, 1)
    }

    func testCustomStringDescription() throws {
        assertCustomStringDescription(key: DuplicateRegistrationDetector.Key(
            serviceType: String.self,
            argumentsType: ((Knit.Resolver)).self,
            name: nil
        ), expectedDescription:
            """
            Duplicate Registration Key
            Service type: String
            Arguments type: Resolver
            Name: `nil`
            """
        )

        assertCustomStringDescription(key: DuplicateRegistrationDetector.Key(
            serviceType: Int.self,
            argumentsType: (Knit.Resolver, Bool).self,
            name: nil
        ), expectedDescription:
            """
            Duplicate Registration Key
            Service type: Int
            Arguments type: (Resolver, Bool)
            Name: `nil`
            """
        )

        assertCustomStringDescription(key: DuplicateRegistrationDetector.Key(
            serviceType: String.self,
            argumentsType: ((Knit.Resolver)).self,
            name: "namedRegistration"
        ), expectedDescription:
            """
            Duplicate Registration Key
            Service type: String
            Arguments type: Resolver
            Name: namedRegistration
            """
        )
    }

}

// MARK: -

private func assertCustomStringDescription(
    key: DuplicateRegistrationDetector.Key,
    expectedDescription: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual("\(key)", expectedDescription, file: file, line: line)
}
