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
            .init(accessLevel: .public, getterConfig: [])
        )

        XCTAssertEqual(
            try parse("@knit internal"),
            .init(accessLevel: .internal, getterConfig: [])
        )

        XCTAssertEqual(
            try parse("@knit hidden"),
            .init(accessLevel: .hidden, getterConfig: [])
        )

        XCTAssertEqual(
            try parse("@knit ignore"),
            .init(accessLevel: .ignore, getterConfig: [])
        )
    }

    func testKnitPrefix() {
        XCTAssertEqual(
            try parse("// @knit public"),
            .init(accessLevel: .public, getterConfig: [])
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
            .init(accessLevel: .public, getterConfig: [])
        )

        XCTAssertEqual(
            try parse("// Comment\n// @knit public\n// another comment"),
            .init(accessLevel: .public, getterConfig: [])
        )
    }

    func testGetterConfig() {
        XCTAssertEqual(
            try parse("// @knit getter-named"),
            .init(accessLevel: nil, getterConfig: [.identifiedGetter(nil)])
        )

        XCTAssertEqual(
            try parse("// @knit getter-named(\"customName\")"),
            .init(accessLevel: nil, getterConfig: [.identifiedGetter("customName")])
        )

        XCTAssertEqual(
            try parse("// @knit getter-callAsFunction"),
            .init(accessLevel: nil, getterConfig: [.callAsFunction])
        )

        XCTAssertEqual(
            try parse("// @knit getter-callAsFunction getter-named"),
            .init(accessLevel: nil, getterConfig: [.identifiedGetter(nil), .callAsFunction])
        )

        XCTAssertEqual(
            try parse("// @knit getter-callAsFunction getter-named"),
            .init(accessLevel: nil, getterConfig: [.identifiedGetter(nil), .callAsFunction])
        )
    }

    func testAssemblyRole() {
        XCTAssertEqual(
            try parse("// @knit secondary"),
            .init(role: .secondary)
        )

        XCTAssertEqual(
            try parse("// @knit primary"),
            .init(role: .primary)
        )

        XCTAssertEqual(
            try parse("// @knit getter-named secondary"),
            .init(getterConfig: [.identifiedGetter(nil)], role: .secondary)
        )
    }

    private func parse(_ comment: String) throws -> KnitDirectives {
        let trivia = Trivia(pieces: [.lineComment(comment)])
        return try KnitDirectives.parse(leadingTrivia: trivia)
    }

}
