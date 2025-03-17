//  Created by Alex Skorulis on 7/2/2025.

@testable import KnitCodeGen
import Foundation
import SwiftSyntax
import XCTest

final class RegistrationEncodingTests: XCTestCase {

    private var registration = Registration(
        service: "MyService",
        name: "Foo",
        accessLevel: .public,
        arguments: [.init(identifier: "ABC", type: "Int")],
        concurrencyModifier: "MainActor",
        customTags: ["tag1", "tag2"],
        getterAlias: "alias",
        functionName: .register,
        ifConfigCondition: ExprSyntax("SOME_FLAG"),
        spi: "Testing"
    )

    func testEncodingOutput() throws {
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
          "customTags" : [
            "tag1",
            "tag2"
          ],
          "functionName" : "register",
          "getterAlias" : "alias",
          "ifConfig" : "SOME_FLAG",
          "name" : "Foo",
          "service" : "MyService",
          "spi" : "Testing"
        }
        """

        XCTAssertEqual(text, expected)
    }

    func testReencoding() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(registration)
        let decoder = JSONDecoder()
        let reencoded = try decoder.decode(Registration.self, from: data)
        XCTAssertEqual(registration, reencoded)
    }

    func testAssembly() throws {
        let assembly = Configuration(
            assemblyName: "MainAssembly",
            moduleName: "MyModule",
            registrations: [.init(service: "ServiceA")],
            targetResolver: "Resolver"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(assembly)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        let expected = """
        {
          "assemblyName" : "MainAssembly",
          "assemblyType" : "ModuleAssembly",
          "directives" : {
            "custom" : [

            ],
            "disablePerformanceGen" : false
          },
          "registrations" : [
            {
              "accessLevel" : "internal",
              "arguments" : [

              ],
              "customTags" : [

              ],
              "functionName" : "register",
              "service" : "ServiceA"
            }
          ],
          "replaces" : [

          ],
          "targetResolver" : "Resolver"
        }
        """

        XCTAssertEqual(text, expected)
    }
}
