//  Created by Alexander skorulis on 28/7/2023.

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

    private func parse(_ comment: String) throws -> KnitDirectives {
        let trivia = Trivia(pieces: [.lineComment(comment)])
        return try KnitDirectives.parse(leadingTrivia: trivia)
    }

}
