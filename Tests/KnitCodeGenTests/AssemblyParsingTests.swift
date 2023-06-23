//
// Copyright © Square, Inc. All rights reserved.
//

@testable import KnitCodeGen
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

        let config = try assertParsesSyntaxTree(sourceFile)
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

        let config = try assertParsesSyntaxTree(sourceFile)
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

        let config = try assertParsesSyntaxTree(sourceFile)
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

        let config = try assertParsesSyntaxTree(sourceFile)
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

        let config = try assertParsesSyntaxTree(sourceFile)
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

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.name, "KeyValueStore", "The first assembly's module name")
        XCTAssertEqual(config.imports.count, 0, "No imports")
        XCTAssertEqual(
            config.registrations.map { $0.service },
            ["KeyValueStore"],
            "Only the registrations from the first assembly"
        )
    }

    func testAdditionalFunctions() throws {
        let sourceFile: SourceFile = """
                class ExampleAssembly: Assembly {
                    func assemble(container: Container) {
                        partialAssemble(container: container)
                    }
                    func partialAssemble(container: Container) {
                        container.register(MyService.self) { }
                    }
                }
            """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.name, "Example")
        XCTAssertEqual(
            config.registrations.map { $0.service },
            ["MyService"],
            "Check that services can be registered in other functions"
        )
    }

    func testTargetResolver() throws {
        let sourceFile: SourceFile = """
                class ExampleAssembly: Assembly {
                    typealias Resolver = MyTargetResolver
                    func assemble(container: Container) {
                    }
                }
            """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.resolverName, "MyTargetResolver")
    }

    func testUsesDefaultResolver() throws {
        let sourceFile: SourceFile = """
                class ExampleAssembly: Assembly {
                    // No typealias for Resolver
                    func assemble(container: Container) {
                    }
                }
            """

        let config = try assertParsesSyntaxTree(
            sourceFile,
            defaultResolverName: "DefaultResolver"
        )
        XCTAssertEqual(config.resolverName, "DefaultResolver")
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

        XCTAssertThrowsError(try assertParsesSyntaxTree(sourceFile)) { error in
            guard case AssemblyParsingError.missingModuleName = error else {
                XCTFail("Incorrect error case")
                return
            }
        }
    }

    func testRegistrationParsingErrorToPrint() throws {
        let sourceFile: SourceFile = """
            class MyAssembly: Assembly {
                func assemble(container: Container) {
                    container.register(A.self) { resolver, arg1 in A(arg: arg1) }
                }
            }
        """

        // Make sure that individual registration errors are bubbled up to be printed
        _ = try assertParsesSyntaxTree(
            sourceFile,
            assertErrorsToPrint: { errors in
                XCTAssertEqual(errors.count, 1)
                if let error = errors.first, case RegistrationParsingError.unwrappedClosureParams = error {
                    // Correct error case
                } else {
                    XCTFail("Incorrect error case")
                }
            }
        )
    }

}

private func assertParsesSyntaxTree(
    _ sourceFile: SourceFile,
    defaultResolverName: String = "Resolver",
    assertErrorsToPrint assertErrorsCallback: (([Error]) -> Void)? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> Configuration {
    var errorsToPrint = [Error]()

    let configuration = try parseSyntaxTree(
        sourceFile,
        defaultResolverName: defaultResolverName,
        errorsToPrint: &errorsToPrint
    )

    if let assertErrorsCallback {
        assertErrorsCallback(errorsToPrint)
    } else {
        XCTAssertEqual(errorsToPrint.count, 0, file: file, line: line)
    }

    return configuration
}
