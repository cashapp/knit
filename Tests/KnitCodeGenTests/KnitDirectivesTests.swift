//
// Copyright © Block, Inc. All rights reserved.
//

@testable import KnitCodeGen
import SwiftSyntax
import XCTest

final class KnitDirectivesTests: XCTestCase {

    func testAccessLevel() throws {
        XCTAssertEqual(
            try parse(" @knit public"),
            .init(accessLevel: .public)
        )

        XCTAssertEqual(
            try parse("@knit internal"),
            .init(accessLevel: .internal)
        )

        XCTAssertEqual(
            try parse("@knit hidden"),
            .init(accessLevel: .hidden)
        )

        XCTAssertEqual(
            try parse("@knit ignore"),
            .init(accessLevel: .ignore)
        )
    }

    func testKnitPrefix() {
        XCTAssertEqual(
            try parse("// @knit public"),
            .init(accessLevel: .public)
        )

        XCTAssertEqual(
            try parse("knit public"),
            .empty
        )

        XCTAssertEqual(
            try parse("public @knit"),
            .empty
        )

        XCTAssertEqual(
            try parse("informational comment"),
            .empty
        )
    }

    func testMultilLneComments() throws {
        XCTAssertEqual(
            try parse("// @knit public\n\n// another comment"),
            .init(accessLevel: .public)
        )

        XCTAssertEqual(
            try parse("// Comment\n// @knit public\n// another comment"),
            .init(accessLevel: .public)
        )
    }

    func testGetterAlias() {
        XCTAssertEqual(
            try parse("// @knit getter-named(\"customName\")"),
            .init(accessLevel: nil, getterAlias: "customName")
        )
    }

    func testSPI() {
        XCTAssertEqual(
            try parse("// @knit @_spi(Testing)"),
            .init(accessLevel: nil, spi: "Testing")
        )

        // Only 1 SPI is supported, the second will cause the parsing to throw
        XCTAssertThrowsError(try parse("// @knit @_spi(First) @_spi(Second)"))
    }

    func testModuleName() {
        XCTAssertEqual(
            try parse("// @knit module-name(\"Test\")"),
            .init(moduleName: "Test")
        )

        XCTAssertEqual(
            try parse("// @knit module-name(\"MyModuleName\")"),
            .init(moduleName: "MyModuleName")
        )

        XCTAssertEqual(
            try parse("// @knit module-name(\"A\")"),
            .init(moduleName: "A")
        )

        XCTAssertThrowsError(try parse("// @knit module-name"))
        XCTAssertThrowsError(try parse("// @knit module-name()"))
    }

    func testPerformanceGen() {
        XCTAssertEqual(
            try parse("// @knit disable-performance-gen"),
            .init(disablePerformanceGen: true)
        )
    }

    func testCustom() {
        XCTAssertEqual(
            try parse("// @knit tag(\"Foo\") tag(\"Bar\")"),
            .init(custom: ["Foo", "Bar"])
        )
    }

    private func parse(_ comment: String) throws -> KnitDirectives {
        let trivia = Trivia(pieces: [.lineComment(comment)])
        return try KnitDirectives.parse(leadingTrivia: trivia)
    }

}
