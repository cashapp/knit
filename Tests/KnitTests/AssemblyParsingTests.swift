//
// Copyright © Square, Inc. All rights reserved.
//

@testable import Knit
import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest

final class AssemblyParsingTests: XCTestCase {

    func testAssemblyImports() throws {
        let sourceFile: SourceFile = """
            import A
            import B // Comment after import should be stripped
            class FooTestAssembly: Assembly { }
            """

        let config = try parseSyntaxTree(sourceFile)
        XCTAssertEqual(
            config.imports.map { $0.description },
            [
                "import A",
                "import B",
            ]
        )
        XCTAssertEqual(config.registrations.count, 0, "No registrations")
    }

    func testTestableImport() throws {
        // Unclear if this is a use case we care about, but we will retain attributes before the import statement
        let sourceFile: SourceFile = """
            @testable import A
            class FooTestAssembly: Assembly { }
            """

        let config = try parseSyntaxTree(sourceFile)
        XCTAssertEqual(
            config.imports.map { $0.description },
            [
                "@testable import A"
            ]
        )
    }

    func testAssemblyModuleName() throws {
        let sourceFile: SourceFile = """
            class FooTestAssembly: Assembly {
                func assemble(container: Container) {
                    container.register(A.self) { }
                }
            }
        """

        let config = try parseSyntaxTree(sourceFile)
        XCTAssertEqual(config.name, "FooTest")
    }

    func testAssemblyStructModuleName() throws {
        let sourceFile: SourceFile = """
            struct FooTestAssembly: Assembly {
                func assemble(container: Container) {
                    container.register(A.self) { }
                }
            }
        """

        let config = try parseSyntaxTree(sourceFile)
        XCTAssertEqual(config.name, "FooTest")
    }

    func testAssemblyRegistrations() throws {
        let sourceFile: SourceFile = """
            class TestAssembly: Assembly {
                func assemble(container: Container) {
                    container.register(A.self) { }
                }
            }
            """

        let config = try parseSyntaxTree(sourceFile)
        XCTAssertEqual(config.name, "Test")
        XCTAssertEqual(config.imports.count, 0, "No imports")
        XCTAssertEqual(
            config.registrations.map { $0.service },
            ["A"]
        )
    }

    func testOnlyFirstOfMultipleAssemblies() throws {
        let sourceFile: SourceFile = """
                class KeyValueStoreAssembly: Assembly {
                    func assemble(container: Container) {
                        container.register(KeyValueStore.self) { }
                    }
                }

                class InMemoryKeyValueStoreAssembly: ModuleAssemblyOverride {
                    func assemble(container: Container) {
                        container.register(Override.self) { }
                    }
                }
            """

        let config = try parseSyntaxTree(sourceFile)
        XCTAssertEqual(config.name, "KeyValueStore", "The first assembly's module name")
        XCTAssertEqual(config.imports.count, 0, "No imports")
        XCTAssertEqual(
            config.registrations.map { $0.service },
            ["KeyValueStore"],
            "Only the registrations from the first assembly"
        )
    }

    // MARK: - ClassDecl Extension

    func testClassDeclExtension() {
        var classDecl: ClassDecl

        classDecl = "class BarAssembly {}"
        XCTAssertEqual(classDecl.moduleNameForAssembly, "Bar")

        classDecl = "public final class FooAssembly {}"
        XCTAssertEqual(classDecl.moduleNameForAssembly, "Foo")

        classDecl = "class AssemblyMissing {}"
        XCTAssertNil(classDecl.moduleNameForAssembly)
    }

    // MARK: - Error Throwing

    func testSyntaxParsingError() {
        let sourceFile: SourceFile = """
                class SomeClass { }
                // missing an assembly
            """

        XCTAssertThrowsError(try parseSyntaxTree(sourceFile)) { error in
            guard case AssemblyParsingError.missingModuleName = error else {
                XCTFail("Incorrect error case")
                return
            }
        }
    }

}
