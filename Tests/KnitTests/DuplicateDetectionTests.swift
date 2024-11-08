//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import XCTest

final class DuplicateDetectionTests: XCTestCase {

    func testBasicDetection() throws {
        var reportedDuplicates = [DuplicateDetection.Key]()
        let duplicateDetection = DuplicateDetection(duplicateWasDetected: { key in
            reportedDuplicates.append(key)
        })
        let container = Container(
            behaviors: [duplicateDetection]
        )

        XCTAssertEqual(reportedDuplicates.count, 0)
        container.register(String.self, factory: { _ in "one" })
        XCTAssertEqual(reportedDuplicates.count, 0)

        container.register(String.self, factory: { _ in "two" })
        XCTAssertEqual(reportedDuplicates.count, 1)
        let firstReport = try XCTUnwrap(reportedDuplicates.first)
        XCTAssert(firstReport.serviceType == String.self)
        XCTAssert(firstReport.argumentsType == (Resolver).self)
        XCTAssertEqual(firstReport.name, nil)

        container.register(String.self, factory: { _ in "three" })
        XCTAssertEqual(reportedDuplicates.count, 2)
    }

    func testNames() throws {
        var reportedDuplicates = [DuplicateDetection.Key]()
        let duplicateDetection = DuplicateDetection(duplicateWasDetected: { key in
            reportedDuplicates.append(key)
        })
        let container = Container(
            behaviors: [duplicateDetection]
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
        XCTAssert(firstReport.argumentsType == (Resolver).self)
        XCTAssertEqual(firstReport.name, "nameOne")
    }

    func testArguments() throws {
        var reportedDuplicates = [DuplicateDetection.Key]()
        let duplicateDetection = DuplicateDetection(duplicateWasDetected: { key in
            reportedDuplicates.append(key)
        })
        let container = Container(
            behaviors: [duplicateDetection]
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
        XCTAssert(firstReport.argumentsType == (Resolver, Int).self)
        XCTAssertEqual(firstReport.name, nil)
    }

    func testNoDuplicates() throws {
        var reportedDuplicates = [DuplicateDetection.Key]()
        let duplicateDetection = DuplicateDetection(duplicateWasDetected: { key in
            reportedDuplicates.append(key)
        })
        let container = Container(
            behaviors: [duplicateDetection]
        )

        container.register(String.self, factory: { _ in "" })
        container.register(Bool.self, factory: { _ in true })
        container.register(Int.self, factory: { _ in 1 })
        XCTAssertEqual(reportedDuplicates.count, 0)
    }

    func testParentContainerNotDuplicate() throws {
        // A parent container is allowed to contain the same registration key as a child container
        // This is not a duplicate but a "shadow" registration

        var reportedDuplicates = [DuplicateDetection.Key]()

        let parentDuplicateDetection = DuplicateDetection(duplicateWasDetected: { key in
            reportedDuplicates.append(key)
        })
        let parentContainer = Container(behaviors: [parentDuplicateDetection])

        let childDuplicateDetection = DuplicateDetection(duplicateWasDetected: { key in
            reportedDuplicates.append(key)
        })
        let childContainer = Container(parent: parentContainer, behaviors: [childDuplicateDetection])

        parentContainer.register(String.self, factory: { _ in "parent" })
        childContainer.register(String.self, factory: { _ in "child" })

        XCTAssertEqual(reportedDuplicates.count, 0)
    }

    func testCustomStringDescription() throws {
        assertCustomStringDescription(key: DuplicateDetection.Key(
            serviceType: String.self,
            argumentsType: ((Resolver)).self,
            name: nil
        ), expectedDescription:
            """
            Duplicate Registration Key
            Service type: String
            Arguments type: Resolver
            Name: `nil`
            """
        )

        assertCustomStringDescription(key: DuplicateDetection.Key(
            serviceType: Int.self,
            argumentsType: (Resolver, Bool).self,
            name: nil
        ), expectedDescription:
            """
            Duplicate Registration Key
            Service type: Int
            Arguments type: (Resolver, Bool)
            Name: `nil`
            """
        )

        assertCustomStringDescription(key: DuplicateDetection.Key(
            serviceType: String.self,
            argumentsType: ((Resolver)).self,
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
    key: DuplicateDetection.Key,
    expectedDescription: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual("\(key)", expectedDescription, file: file, line: line)
}
