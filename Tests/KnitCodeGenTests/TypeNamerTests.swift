// Created by Alexander skorulis on 6/7/2023.
// Copyright © Square, Inc. All rights reserved. 

import Foundation
@testable import KnitCodeGen
import XCTest

final class TypeNamerTests: XCTestCase {

    func testTypeNaming() {
        XCTAssertEqual(
            TypeNamer.computedVariableName(type: "String"),
            "string"
        )

        XCTAssertEqual(
            TypeNamer.computedVariableName(type: "URL"),
            "url"
        )

        XCTAssertEqual(
            TypeNamer.computedVariableName(type: "() -> URL"),
            "closure"
        )

        XCTAssertEqual(
            TypeNamer.computedVariableName(type: "MyService"),
            "myService"
        )

        XCTAssertEqual(
            TypeNamer.computedVariableName(type: "Result<String, Error>"),
            "result"
        )

        XCTAssertEqual(
            TypeNamer.computedVariableName(type: "Result<String, Error>"),
            "result"
        )

        XCTAssertEqual(
            TypeNamer.computedVariableName(type: "[ServiceA]"),
            "serviceA"
        )

        XCTAssertEqual(
            TypeNamer.computedVariableName(type: "[ServiceA]?"),
            "serviceA"
        )

    }

    func testClosureDetection() {
        XCTAssertTrue(TypeNamer.isClosure(type: "() -> Void"))
        XCTAssertFalse(TypeNamer.isClosure(type: "String"))
    }

}
