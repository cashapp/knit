//
// Copyright © Block, Inc. All rights reserved.
//

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

        assertComputedIdentifier(
            type: "(String, Int?)",
            expectedIdentifier: "stringInt"
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

    func testPrefixedName() {
        assertComputedIdentifier(
            type: "UIApplication",
            expectedIdentifier: "uiApplication"
        )
        assertComputedIdentifier(
            type: "NSURLSession",
            expectedIdentifier: "nsurlSession"
        )
    }

    func testAnyPrefix() {
        assertComputedIdentifier(
            type: "(any AppTransitionObservable)",
            expectedIdentifier: "appTransitionObservable"
        )

        assertComputedIdentifier(
            type: "any AppTransitionObservable",
            expectedIdentifier: "appTransitionObservable"
        )
    }

    func testFactoryRule() {
        assertComputedIdentifier(
            type: "MyClass.Factory",
            expectedIdentifier: "myClassFactory"
        )

        assertComputedIdentifier(
            type: "Module.MyClass.Factory",
            expectedIdentifier: "myClassFactory"
        )

        assertComputedIdentifier(
            type: "Factory",
            expectedIdentifier: "factory"
        )
    }

    func testSuffixRule() {
        assertComputedIdentifier(
            type: "AnyPublisher<String>",
            expectedIdentifier: "stringPublisher"
        )

        assertComputedIdentifier(
            type: "AnyPublisher<MyType?, Never>",
            expectedIdentifier: "myTypePublisher"
        )

        assertComputedIdentifier(
            type: "CurrentValueSubject<String>",
            expectedIdentifier: "stringSubject"
        )

        assertComputedIdentifier(
            type: "ValueProvider<Int>",
            expectedIdentifier: "intProvider"
        )

        assertComputedIdentifier(
            type: "Future<MyClass, Never>",
            expectedIdentifier: "myClassFuture"
        )

    }

    func testMultipleGenerics() {
        assertComputedIdentifier(
            type: "AnyPublisher<Set<AppletId>, Never>",
            expectedIdentifier: "appletIdSetPublisher"
        )

        assertComputedIdentifier(
            type: "Outer<Inner<Content>>",
            expectedIdentifier: "outer"
        )

        assertComputedIdentifier(
            type: "Set<Inner<Content>>",
            expectedIdentifier: "innerSet"
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
