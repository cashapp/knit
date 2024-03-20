//
// Copyright © Block, Inc. All rights reserved.
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
            class FooTestAssembly: ModuleAssembly { }
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
        XCTAssertEqual(config.assemblyType, "ModuleAssembly")
    }

    func testDebugWrappedAssemblyImports() throws {
        let sourceFile: SourceFileSyntax = """
            #if DEBUG
            import A
            #endif
            import B // Comment after import should be stripped
            class FooTestAssembly: Assembly { }
            """
        

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.imports.count, 2)
        XCTAssertEqual(config.imports[0].decl.description, "import A")
        XCTAssertEqual(config.imports[0].ifConfigCondition?.description, "DEBUG")
        XCTAssertEqual(config.imports[1].decl.description, "import B")
        XCTAssertNil(config.imports[1].ifConfigCondition)

        XCTAssertEqual(config.registrations.count, 0, "No registrations")
    }

    func testIfElseImportError() throws {
        let sourceFile: SourceFileSyntax = """
            #if DEBUG
            import A
            #else
            import B
            #endif
            class FooTestAssembly: Assembly { }
            """

        _ = try assertParsesSyntaxTree(sourceFile, assertErrorsToPrint: { errors in
            XCTAssertEqual(errors.count, 1)
            XCTAssertEqual(errors[0].localizedDescription, "Invalid IfConfig expression: #else")
        })
    }

    func testElseInOtherStatements() throws {
        let sourceFile: SourceFileSyntax = """
            class FooTestAssembly: Assembly { }

            func randomFunction() -> Bool {
                #if DEBUG
                return true
                #else
                return false
                #endif
            }
            """
        
        // Check that no errors occur
        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.registrations.count, 0, "No registrations")
    }

    func testTestableImport() throws {
        // Unclear if this is a use case we care about, but we will retain attributes before the import statement
        let sourceFile: SourceFileSyntax = """
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
        let sourceFile: SourceFileSyntax = """
            class FooTestAssembly: Assembly {
                func assemble(container: Container) {
                    container.register(A.self) { }
                }
            }
        """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.assemblyName, "FooTestAssembly")
        XCTAssertEqual(config.assemblyType, "Assembly")
    }

    func testAssemblyStructModuleName() throws {
        let sourceFile: SourceFileSyntax = """
            struct FooTestAssembly: Assembly {
                func assemble(container: Container) {
                    container.register(A.self) { }
                }
            }
        """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.assemblyName, "FooTestAssembly")
    }

    func testAssemblyRegistrations() throws {
        let sourceFile: SourceFileSyntax = """
            class TestAssembly: Assembly {
                func assemble(container: Container) {
                    container.register(A.self) { }
                }
            }
            """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.assemblyName, "TestAssembly")
        XCTAssertEqual(config.imports.count, 0, "No imports")
        XCTAssertEqual(
            config.registrations.map { $0.service },
            ["A"]
        )
    }

    func testKnitDirectives() throws {
        let sourceFile: SourceFileSyntax = """
            // @knit public getter-named
            class TestAssembly: Assembly {
                func assemble(container: Container) {
                    container.register(A.self) { }
                    // @knit internal getter-callAsFunction
                    container.register(B.self) { }
                }
            }
            """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(
            config.registrations,
            [
                .init(service: "A", accessLevel: .public, getterConfig: [.identifiedGetter(nil)]),
                .init(service: "B", accessLevel: .internal, getterConfig: [.callAsFunction])
            ]
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

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.assemblyName, "KeyValueStoreAssembly", "The first assembly's module name")
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
                        Self.fulfillAbstractRegistrations(container: container)
                    }
                    func partialAssemble(container: Container) {
                        container.register(MyService.self) { }
                    }
                    static func fulfillAbstractRegistrations(container: Container) {
                        // @knit hidden
                        container.register(OtherService.self) { }
                    }
                }
            """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.assemblyName, "ExampleAssembly")
        XCTAssertEqual(
            config.registrations,
            [
                .init(service: "MyService", accessLevel: .internal), // `partialAssemble`
                .init(service: "OtherService", accessLevel: .hidden), // `fulfillAbstractRegistrations`
            ],
            "Check that services can be registered in other functions"
        )
    }

    func testAdditionalFunctionsInComputedPropertyAreNotParsed() throws {
        let sourceFile: SourceFileSyntax = """
                class ExampleAssembly: Assembly {
                    func assemble(container: Container) {
                        container.register(MyService.self) { }
                    }
                    static var dependencies: [any ModuleAssembly.Type] {
                        return ExampleAssembly.generatedDependencies.filter { $0.resolverType == AppResolver.self }
                    }
                }
            """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.assemblyName, "ExampleAssembly")
        XCTAssertEqual(config.targetResolver, "Resolver")
        XCTAssertEqual(
            config.registrations,
            [
                .init(service: "MyService", accessLevel: .internal),
            ],
            "The `dependencies` computed property should be ignored"
        )
    }

    // MARK: - ClassDecl Extension

    func testClassDeclExtension() throws {
        var classDecl: ClassDeclSyntax

        func makeClassDecl(from string: String) throws -> ClassDeclSyntax {
            return try ClassDeclSyntax("\(raw: string)")
        }

        classDecl = try makeClassDecl(from: "class BarAssembly {}")
        XCTAssertEqual(classDecl.namesForAssembly?.0, "BarAssembly")
        XCTAssertEqual(classDecl.namesForAssembly?.1, "Bar")

        classDecl = try makeClassDecl(from: "public final class FooAssembly {}")
        XCTAssertEqual(classDecl.namesForAssembly?.0, "FooAssembly")
        XCTAssertEqual(classDecl.namesForAssembly?.1, "Foo")

        classDecl = try makeClassDecl(from: "class AssemblyMissing {}")
        XCTAssertNil(classDecl.namesForAssembly)
    }

    // MARK: - Error Throwing

    func testSyntaxParsingError() {
        let sourceFile: SourceFileSyntax = """
                class SomeClass { }
                // missing an assembly
            """

        XCTAssertThrowsError(try assertParsesSyntaxTree(sourceFile)) { error in
            guard case AssemblyParsingError.missingAssemblyName = error else {
                XCTFail("Incorrect error case")
                return
            }
        }
    }

    func testRegistrationParsingErrorToPrint() throws {
        let sourceFile: SourceFileSyntax = """
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

    func testCustomResolver() throws {
        let sourceFile: SourceFileSyntax = """
            class MyAssembly: Assembly {
                typealias TargetResolver = TestResolver
            }
        """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.assemblyName, "MyAssembly")
        XCTAssertEqual(config.targetResolver, "TestResolver")
    }

    func testCustomResolverWhenDisabled() throws {
        let sourceFile: SourceFileSyntax = """
            class MyAssembly: Assembly {
                typealias TargetResolver = TestResolver
            }
        """

        let config = try assertParsesSyntaxTree(sourceFile, useTargetResolver: false)
        XCTAssertEqual(config.assemblyName, "MyAssembly")
        XCTAssertEqual(config.targetResolver, "Resolver")
    }

    func testIfDefElseFailure() throws {
        let sourceFile: SourceFileSyntax = """
            class ExampleAssembly: Assembly {
                func assemble(container: Container) {
                    #if SOME_FLAG
                    container.autoregister(B.self, initializer: B.init)
                    #else
                    container.autoregister(C.self, initializer: C.init)
                    #endif
                }
            }
        """

        // Make sure that individual registration errors are bubbled up to be printed
        _ = try assertParsesSyntaxTree(
            sourceFile,
            assertErrorsToPrint: { errors in
                XCTAssertEqual(errors.count, 1)
                XCTAssertEqual(
                    errors.first?.localizedDescription,
                    "Invalid IfConfig expression: #else"
                )
            }
        )
    }

    func testIfDefParsing() throws {
        let sourceFile: SourceFileSyntax = """
            class ExampleAssembly: Assembly {
                func assemble(container: Container) {
                    #if SOME_FLAG
                    container.autoregister(A.self, initializer: A.init)
                    #endif

                    #if SOME_FLAG && !ANOTHER_FLAG
                    container.autoregister(B.self, initializer: B.init)
                    container.autoregister(C.self, initializer: C.init)
                    #endif
                }
            }
        """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.assemblyName, "ExampleAssembly")
        XCTAssertEqual(config.registrations.count, 3)

        XCTAssertEqual(config.registrations[0].service, "A")
        XCTAssertEqual(config.registrations[0].ifConfigCondition?.description, "SOME_FLAG")

        XCTAssertEqual(config.registrations[1].service, "B")
        XCTAssertEqual(config.registrations[1].ifConfigCondition?.description, "SOME_FLAG && !ANOTHER_FLAG")

        XCTAssertEqual(config.registrations[2].service, "C")
        XCTAssertEqual(config.registrations[2].ifConfigCondition?.description, "SOME_FLAG && !ANOTHER_FLAG")
    }

    func testIfSimulatorParsing() throws {
        let sourceFile: SourceFileSyntax = """
            class ExampleAssembly: Assembly {
                func assemble(container: Container) {
                    #if targetEnvironment(simulator)
                    container.autoregister(A.self, initializer: A.init)
                    #endif
                }
            }
        """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.registrations.count, 1)
        XCTAssertEqual(
            config.registrations.first?.ifConfigCondition?.description,
            "targetEnvironment(simulator)"
        )
    }

    func testNestedIfConfig() throws {
        let sourceFile: SourceFileSyntax = """
            class ExampleAssembly: Assembly {
                func assemble(container: Container) {
                    #if DEBUG
                    #if FEATURE
                    container.autoregister(A.self, initializer: A.init)
                    #endif
                    #endif
                }
            }
        """

        // Make sure that individual registration errors are bubbled up to be printed
        _ = try assertParsesSyntaxTree(
            sourceFile,
            assertErrorsToPrint: { errors in
                XCTAssertEqual(errors.count, 1)
                XCTAssertEqual(
                    errors.first?.localizedDescription,
                    "Nested #if statements are not supported"
                )
            }
        )
    }

    func testIgnoredConfiguration() throws {
        let sourceFile: SourceFileSyntax = """
            // @knit ignore
            class MyAssembly: Assembly {
                typealias TargetResolver = TestResolver
            }
        """
        var errorsToPrint = [Error]()

        let parser = try AssemblyParser(defaultTargetResolver: "Resolver", useTargetResolver: true)

        let configuration = try parser.parseSyntaxTree(
            sourceFile,
            errorsToPrint: &errorsToPrint
        )

        XCTAssertEqual(errorsToPrint.count, 0)
        XCTAssertNil(configuration)
    }

    func testIgnoredRegistration() throws {
        let sourceFile: SourceFileSyntax = """
            class MyAssembly: Assembly {
                func assemble(container: Container) {
                    // @knit ignore
                    container.register(A.self) { }
                }
            }
        """
        
        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.registrations.count, 0)
    }

    func testCustomModuleName() throws {
        let sourceFile: SourceFileSyntax = """
            // @knit module-name("Custom")
            class MyAssembly: Assembly {
            }
        """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.directives.moduleName, "Custom")
        XCTAssertEqual(config.moduleName, "Custom")
        XCTAssertEqual(config.assemblyName, "MyAssembly")
    }

    func testModuleNameRegex() throws {
        let sourceFile: SourceFileSyntax = """
            class MyAssembly: Assembly {
            }
        """

        var errorsToPrint = [Error]()

        let parser = try AssemblyParser(moduleNameRegex: "(\\w+)\\/Sources\\/DI\\/.*Assembly\\.swift")
        let config = try parser.parseSyntaxTree(
            sourceFile,
            path: "/App/OtherModule/Sources/DI/SomeAssembly.swift",
            errorsToPrint: &errorsToPrint
        )

        XCTAssertEqual(config?.assemblyName, "MyAssembly")
        XCTAssertEqual(config?.moduleName, "OtherModule")
        
        let config2 = try parser.parseSyntaxTree(
            sourceFile,
            path: "/Non/Matching/Path/SomeAssembly.swift",
            errorsToPrint: &errorsToPrint
        )

        XCTAssertEqual(config2?.assemblyName, "MyAssembly")
        XCTAssertEqual(config2?.moduleName, "My")
    }

}

private func assertParsesSyntaxTree(
    _ sourceFile: SourceFileSyntax,
    assertErrorsToPrint assertErrorsCallback: (([Error]) -> Void)? = nil,
    useTargetResolver: Bool = true,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> Configuration {
    var errorsToPrint = [Error]()

    let parser = try AssemblyParser(defaultTargetResolver: "Resolver", useTargetResolver: useTargetResolver)

    let configuration = try parser.parseSyntaxTree(
        sourceFile,
        errorsToPrint: &errorsToPrint
    )

    if let assertErrorsCallback {
        assertErrorsCallback(errorsToPrint)
    } else {
        XCTAssertEqual(errorsToPrint.count, 0, file: file, line: line)
    }

    return try XCTUnwrap(configuration)
}
