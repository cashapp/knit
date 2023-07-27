// Created by Alexander skorulis on 6/7/2023.
// Copyright © Square, Inc. All rights reserved. 

import Foundation
@testable import KnitCodeGen
import XCTest

final class TypeNamerTests: XCTestCase {

    func testTypeComputedIdentifiers() {
        assertComputedIdentifier(
            type: "String",
            expectedIdentifier: "string"
        )

        assertComputedIdentifier(
            type: "URL",
            expectedIdentifier: "url"
        )

        assertComputedIdentifier(
            type: "() -> URL",
            expectedIdentifier: "closure"
        )

        assertComputedIdentifier(
            type: "MyService",
            expectedIdentifier: "myService"
        )

        assertComputedIdentifier(
            type: "Result<String, Error>",
            expectedIdentifier: "result"
        )

        assertComputedIdentifier(
            type: "Result<String, Error>",
            expectedIdentifier: "result"
        )

        assertComputedIdentifier(
            type: "[ServiceA]",
            expectedIdentifier: "serviceA"
        )

        assertComputedIdentifier(
            type: "[ServiceA]?",
            expectedIdentifier: "serviceA"
        )

        assertComputedIdentifier(
            type: "[Key: Value]",
            expectedIdentifier: "keyValue"
        )

        assertComputedIdentifier(
            type: "ProtocolA & ProtocolB",
            expectedIdentifier: "protocolAProtocolB"
        )

    }

    func testClosureDetection() {
        XCTAssertTrue(TypeNamer.isClosure(type: "() -> Void"))
        XCTAssertFalse(TypeNamer.isClosure(type: "String"))
    }

    func testSanitizeWithGenerics() {
        XCTAssertEqual(
            TypeNamer.sanitizeType(type: "Array<String>", keepGenerics: true),
            "Array_String"
        )

        XCTAssertEqual(
            TypeNamer.sanitizeType(type: "Result<String, Error>", keepGenerics: true),
            "Result_String_Error"
        )

        XCTAssertEqual(
            TypeNamer.sanitizeType(type: "Array<String>", keepGenerics: false),
            "Array"
        )
    }

}

private func assertComputedIdentifier(
    type: String,
    expectedIdentifier: String,
    file: StaticString = #file,
    line: UInt = #line
) {
    XCTAssertEqual(
        TypeNamer.computedIdentifierName(type: type),
        expectedIdentifier,
        file: file,
        line: line
    )
}
