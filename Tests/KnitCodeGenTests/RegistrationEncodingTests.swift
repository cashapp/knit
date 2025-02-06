//  Created by Alex Skorulis on 7/2/2025.

@testable import KnitCodeGen
import Foundation
import SwiftSyntax
import XCTest

final class RegistrationEncodingTests: XCTestCase {

    func testEncoding() throws {
        var registration = Registration(
            service: "MyService",
            name: "Foo",
            accessLevel: .public,
            arguments: [.init(identifier: "ABC", type: "Int")],
            concurrencyModifier: "MainActor",
            getterConfig: [.identifiedGetter("alias")],
            functionName: .register,
            spi: "Testing"
        )
        registration.ifConfigCondition = ExprSyntax("SOME_FLAG")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(registration)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        let expected = """
        {
          "accessLevel" : "public",
          "arguments" : [
            {
              "identifier" : {
                "fixed" : {
                  "_0" : "ABC"
                }
              },
              "type" : "Int"
            }
          ],
          "concurrencyModifier" : "MainActor",
          "functionName" : "register",
          "getterConfig" : [
            {
              "identifiedGetter" : {
                "_0" : "alias"
              }
            }
          ],
          "ifConfigString" : "SOME_FLAG",
          "name" : "Foo",
          "service" : "MyService",
          "spi" : "Testing"
        }
        """

        XCTAssertEqual(text, expected)
    }
}
