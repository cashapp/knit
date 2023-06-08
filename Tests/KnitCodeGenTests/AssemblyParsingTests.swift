//
// Copyright © Square, Inc. All rights reserved.
//

@testable import KnitCodeGen
import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest

final class AssemblyParsingTests: XCTestCase {

    func testAssemblyImports() throws {
        let sourceFile: SourceFileSyntax = """
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
        let sourceFile: SourceFileSyntax = """
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
        let sourceFile: SourceFileSyntax = """
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
        let sourceFile: SourceFileSyntax = """
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
        let sourceFile: SourceFileSyntax = """
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
        let sourceFile: SourceFileSyntax = """
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

    func testAdditionalFunctions() throws {
        let sourceFile: SourceFileSyntax = """
                class ExampleAssembly: Assembly {
                    func assemble(container: Container) {
                        partialAssemble(container: container)
                    }
                    func partialAssemble(container: Container) {
                        container.register(MyService.self) { }
                    }
                }
            """

        let config = try parseSyntaxTree(sourceFile)
        XCTAssertEqual(config.name, "Example")
        XCTAssertEqual(
            config.registrations.map { $0.service },
            ["MyService"],
            "Check that services can be registered in other functions"
        )
    }

    // MARK: - ClassDecl Extension

    func testClassDeclExtension() throws {
        var classDecl: ClassDeclSyntax

        classDecl = ClassDeclSyntax(DeclSyntax("class BarAssembly {}"))!
        XCTAssertEqual(classDecl.moduleNameForAssembly, "Bar")

        classDecl = ClassDeclSyntax(DeclSyntax("public final class FooAssembly {}"))!
        XCTAssertEqual(classDecl.moduleNameForAssembly, "Foo")

        classDecl = ClassDeclSyntax(DeclSyntax("class AssemblyMissing {}"))!
        XCTAssertNil(classDecl.moduleNameForAssembly)
    }

    // MARK: - Error Throwing

    func testSyntaxParsingError() {
        let sourceFile: SourceFileSyntax = """
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
