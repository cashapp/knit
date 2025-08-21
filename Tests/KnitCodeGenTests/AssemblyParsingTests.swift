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
            class FooTestAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
            }
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
        XCTAssertEqual(config.assemblyType, .moduleAssembly)
        XCTAssertEqual(config.assemblyShortName, "FooTest")
    }

    func testSubmoduleResolver() throws {
        let sourceFile: SourceFileSyntax = """
            import OtherModule
            class FooTestAssembly: ModuleAssembly {
                typealias TargetResolver = OtherModule.Resolver
            }
            """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.targetResolver, "OtherModule.Resolver")
    }

    func testDebugWrappedAssemblyImports() throws {
        let sourceFile: SourceFileSyntax = """
            #if DEBUG
            import A
            #endif
            import B // Comment after import should be stripped
            class FooTestAssembly: ModuleAssembly { 
                typealias TargetResolver = TestResolver
            }
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
            class FooTestAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
            }
            """

        _ = try assertParsesSyntaxTree(sourceFile, assertErrorsToPrint: { errors in
            XCTAssertEqual(errors.count, 1)
            XCTAssertEqual(errors[0].localizedDescription, "Invalid IfConfig expression: #else")
        })
    }

    func testElseInOtherStatements() throws {
        let sourceFile: SourceFileSyntax = """
            class FooTestAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
            }

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
            class FooTestAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
            }
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
            class FooTestAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver

                func assemble(container: Container) {
                    container.register(A.self) { }
                }
            }
        """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.assemblyName, "FooTestAssembly")
        XCTAssertEqual(config.assemblyType, .moduleAssembly)
    }

    func testAssemblyStructModuleName() throws {
        let sourceFile: SourceFileSyntax = """
            struct FooTestAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver

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
            class TestAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver

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

    func testAssemblyTypes() throws {
        let sourceFilesAndExpected: [(SourceFileSyntax, Configuration.AssemblyType)] = [
            (
                """
                class TestAssembly: ModuleAssembly {
                    typealias TargetResolver = TestResolver
                    func assemble(container: Container) {}
                }
                """,
                .moduleAssembly
            ),

            (
                """
                class TestAssembly: AutoInitModuleAssembly {
                    typealias TargetResolver = TestResolver
                    func assemble(container: Container) {}
                }
                """,
                .autoInitAssembly
            ),

            (
                """
                class TestAssembly: AbstractAssembly {
                    typealias TargetResolver = TestResolver
                    func assemble(container: Container) {}
                }
                """,
                .abstractAssembly
            ),
        ]

        try sourceFilesAndExpected.enumerated().forEach { (index, tuple) in
            let (sourceFile, expectedType) = tuple
            let config = try assertParsesSyntaxTree(sourceFile)
            XCTAssertEqual(
                config.assemblyType,
                expectedType,
                "Failed for tuple at index \(index)"
            )
        }

    }

    func testMissingAssemblyType() throws {
        // Use the Swinject `Assembly` type (which is no longer supported)
        let sourceFile: SourceFileSyntax = """
            class TestAssembly: Assembly {
                typealias TargetResolver = TestResolver
            }
            """

        XCTAssertThrowsError(
            try assertParsesSyntaxTree(sourceFile),
            "Show throw error that Assembly type is missing",
            { error in
                guard case AssemblyParsingError.missingAssemblyType = error else {
                    XCTFail("Incorrect error type")
                    return
                }
            }
        )
    }

    func testKnitDirectives() throws {
        let sourceFile: SourceFileSyntax = """
            // @knit public
            class TestAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                func assemble(container: Container) {
                    container.register(A.self) { }
                    // @knit internal alias("bb")
                    container.register(B.self) { }
                }
            }
            """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(
            config.registrations,
            [
                .init(service: "A", accessLevel: .public),
                .init(service: "B", accessLevel: .internal, getterAlias: "bb")
            ]
        )
    }

    func testOnlyFirstOfMultipleAssemblies() throws {
        let sourceFile: SourceFileSyntax = """
                class KeyValueStoreAssembly: ModuleAssembly {
                    typealias TargetResolver = TestResolver
                    func assemble(container: Container) {
                        container.register(KeyValueStore.self) { }
                    }
                }

                // @knit ignore
                class InMemoryKeyValueStoreAssembly: ModuleAssembly {
                    typealias TargetResolver = TestResolver
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
                class ExampleAssembly: ModuleAssembly {
                    typealias TargetResolver = TestResolver
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
                class ExampleAssembly: ModuleAssembly {
                    typealias TargetResolver = TestResolver
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
        XCTAssertEqual(config.targetResolver, "TestResolver")
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
            guard case AssemblyParsingError.noAssembliesFound = error else {
                XCTFail("Incorrect error case")
                return
            }
        }
    }

    func testRegistrationParsingErrorToPrint() throws {
        let sourceFile: SourceFileSyntax = """
            class MyAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
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

    func testTargetResolver() throws {
        let sourceFile: SourceFileSyntax = """
            class MyAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
            }
        """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.assemblyName, "MyAssembly")
        XCTAssertEqual(config.targetResolver, "TestResolver")
    }

    func testMissingTargetResolver() throws {
        let sourceFile: SourceFileSyntax = """
            class MyAssembly: ModuleAssembly {
                // typealias TargetResolver = TestResolver
            }
        """

        XCTAssertThrowsError(
            try assertParsesSyntaxTree(sourceFile),
            "Should throw error for missing TargetResolver declaration",
            { error in
                guard case AssemblyParsingError.missingTargetResolver = error else {
                    XCTFail("Incorrect error case")
                    return
                }
            }
        )
    }

    func testIfDefElseFailure() throws {
        let sourceFile: SourceFileSyntax = """
            class ExampleAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                func assemble(container: Container) {
                    #if SOME_FLAG
                    container.register(B.self, factory: B.init)
                    #else
                    container.register(C.self, factory: C.init)
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
            class ExampleAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                func assemble(container: Container) {
                    #if SOME_FLAG
                    container.register(A.self, factory: A.init)
                    #endif

                    #if SOME_FLAG && !ANOTHER_FLAG
                    container.register(B.self, factory: B.init)
                    container.register(C.self, factory: C.init)
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
            class ExampleAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                func assemble(container: Container) {
                    #if targetEnvironment(simulator)
                    container.register(A.self, factory: A.init)
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
            class ExampleAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                func assemble(container: Container) {
                    #if DEBUG
                    #if FEATURE
                    container.register(A.self, factory: A.init)
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

        let parser = try AssemblyParser()

        let configurations = try parser.parseSyntaxTree(
            sourceFile,
            errorsToPrint: &errorsToPrint
        )

        XCTAssertEqual(errorsToPrint.count, 0)
        XCTAssertEqual(configurations.count, 0)
    }

    func testMultipleConfigurations() throws {
        let sourceFile: SourceFileSyntax = """
            class MyAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                func assemble(container: Container) {
                    container.register(A.self) { }
                }
            }

            // @knit module-name("My")
            class MySecondAssembly: ModuleAssembly {
                typealias TargetResolver = AppResolver
                func assemble(container: Container) {
                    container.register(B.self) { }
                }
            }
        """
        var errorsToPrint = [Error]()

        let parser = try AssemblyParser()

        let configurations = try parser.parseSyntaxTree(
            sourceFile,
            errorsToPrint: &errorsToPrint
        )

        XCTAssertEqual(errorsToPrint.count, 0)
        XCTAssertEqual(configurations.count, 2)
        let config1 = configurations[0]
        let config2 = configurations[1]
        XCTAssertEqual(config1.assemblyName, "MyAssembly")
        XCTAssertEqual(config1.targetResolver, "TestResolver")
        XCTAssertEqual(config1.assemblyType, .moduleAssembly)

        XCTAssertEqual(config2.assemblyName, "MySecondAssembly")
        XCTAssertEqual(config2.targetResolver, "AppResolver")
        XCTAssertEqual(config2.assemblyType, .moduleAssembly)
    }

    func testIgnoredRegistration() throws {
        let sourceFile: SourceFileSyntax = """
            class MyAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
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
            class MyAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
            }
        """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.directives.moduleName, "Custom")
        XCTAssertEqual(config.moduleName, "Custom")
        XCTAssertEqual(config.assemblyName, "MyAssembly")
    }

    func testModuleNameRegex() throws {
        let sourceFile: SourceFileSyntax = """
            class MyAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
            }
        """

        var errorsToPrint = [Error]()

        let parser = try AssemblyParser(moduleNameRegex: "(\\w+)\\/Sources\\/DI\\/.*Assembly\\.swift")
        let config = try parser.parseSyntaxTree(
            sourceFile,
            path: "/App/OtherModule/Sources/DI/SomeAssembly.swift",
            errorsToPrint: &errorsToPrint
        ).first

        XCTAssertEqual(config?.assemblyName, "MyAssembly")
        XCTAssertEqual(config?.moduleName, "OtherModule")
        
        let config2 = try parser.parseSyntaxTree(
            sourceFile,
            path: "/Non/Matching/Path/SomeAssembly.swift",
            errorsToPrint: &errorsToPrint
        ).first

        XCTAssertEqual(config2?.assemblyName, "MyAssembly")
        XCTAssertEqual(config2?.moduleName, "My")
    }

    func testAbstractAssemblyWithNonAbstractRegistrations() throws {
        let sourceFile: SourceFileSyntax = """
            class MyAbstractAssembly: AbstractAssembly {
                typealias TargetResolver = TestResolver
                func assemble(container: Container) {
                    container.register(A.self) { }
                }
            }
        """

        _ = try assertParsesSyntaxTree(
            sourceFile,
            assertErrorsToPrint: { errors in
                XCTAssertEqual(errors.count, 1)
                XCTAssertEqual(
                    errors.first?.localizedDescription,
                    "`AbstractAssembly`s may only contain Abstract registrations"
                )
            }
        )
    }

    func testNonAbstractAssemblyAbstractRegistrations() throws {
        let sourceFile: SourceFileSyntax = """
            class MyAssembly: AutoInitModuleAssembly {
                typealias TargetResolver = TestResolver
                func assemble(container: Container) {
                    container.registerAbstract(A.self) { }
                }
            }
        """

        _ = try assertParsesSyntaxTree(
            sourceFile,
            assertErrorsToPrint: { errors in
                XCTAssertEqual(errors.count, 1)
                XCTAssertEqual(
                    errors.first?.localizedDescription,
                    "`AutoInitModuleAssembly`'s cannot contain registerAbstract registrations"
                )
            }
        )
    }

    func testAssemblyReplaces() throws {
        let sourceFile: SourceFileSyntax = """
            class TestAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                func assemble(container: Container) {
                    container.register(A.self) { }
                }
                static var replaces: [any ModuleAssembly.Type] {
                    [RealAssembly.self, SecondAssembly.self]
                }
            }
            """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.replaces, ["RealAssembly", "SecondAssembly"])
    }

    func testReplacesAsLet() throws {
        let sourceFile: SourceFileSyntax = """
            class TestAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                func assemble(container: Container) {
                    container.register(A.self) { }
                }
                static let replaces: [any ModuleAssembly.Type] = [RealAssembly.self, SecondAssembly.self]
            }
            """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.replaces, ["RealAssembly", "SecondAssembly"])
    }
    
    func testInvalidReplaces() throws {
        let sourceFile: SourceFileSyntax = """
            class TestAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                static lazy var replaces: [any ModuleAssembly.Type] = {
                []
            }()
            """

        _ = try assertParsesSyntaxTree(
            sourceFile,
            assertErrorsToPrint: { errors in
                XCTAssertEqual(errors.count, 1)
                XCTAssertEqual(
                    errors.first?.localizedDescription,
                    "Unexpected replaces syntax"
                )
            }
        )
    }

    func testFakeAssembly() throws {
        let sourceFile: SourceFileSyntax = """
            class TestAssembly: FakeAssembly {
                typealias TargetResolver = TestResolver
                typealias ReplacedAssembly = RealAssembly
            }
            """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.replaces, ["RealAssembly"])
        XCTAssertEqual(config.assemblyType, .fakeAssembly)
        XCTAssertEqual(config.assemblyName, "TestAssembly")
    }

    func testFakeAssemblyCustomReplaces() throws {
        let sourceFile: SourceFileSyntax = """
            class TestAssembly: FakeAssembly {
                typealias TargetResolver = TestResolver
                typealias ReplacedAssembly = RealAssembly
                static var replaces: [any ModuleAssembly.Type] { [
                    RealAssembly.self,
                    AdditionalAssembly.self,
                ] }
            }
            """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.replaces, [
            "RealAssembly",
            "AdditionalAssembly"
        ])
        XCTAssertEqual(config.assemblyType, .fakeAssembly)
    }

    func testFakeAssemblyCustomReplaces_missingReplacedAssembly() throws {
        let sourceFile: SourceFileSyntax = """
            class TestAssembly: FakeAssembly {
                typealias TargetResolver = TestResolver
                typealias ReplacedAssembly = RealAssembly
                static var replaces: [any ModuleAssembly.Type] { [
                    AdditionalAssembly.self
                    // RealAssembly is missing
                ] }
            }
            """

        let config = try assertParsesSyntaxTree(
            sourceFile,
            assertErrorsToPrint: { errors in
                XCTAssertEqual(errors.count, 1)
                let error = try XCTUnwrap(errors.first)
                if case ReplacesParsingError.missingReplacedAssembly = error {
                    // Correct, `replaces` is missing `RealAssembly`
                } else {
                    XCTFail("Incorrect error type")
                }
            }
        )
        XCTAssertEqual(config.replaces, ["AdditionalAssembly"])
        XCTAssertEqual(config.assemblyType, .fakeAssembly)
    }

    func testFakeAssemblyCustomReplaces_redundantStaticReplaces() throws {
        let sourceFile: SourceFileSyntax = """
            class TestAssembly: FakeAssembly {
                typealias TargetResolver = TestResolver
                typealias ReplacedAssembly = RealAssembly

                // Redundant declaration, should be removed
                static var replaces: [any ModuleAssembly.Type] { [
                    RealAssembly.self
                ] }
            }
            """

        let config = try assertParsesSyntaxTree(
            sourceFile,
            assertErrorsToPrint: { errors in
                XCTAssertEqual(errors.count, 1)
                let error = try XCTUnwrap(errors.first)
                if case ReplacesParsingError.redundantDeclaration = error {
                    // Correct, `replaces` declaration is redundant
                } else {
                    XCTFail("Incorrect error type")
                }
            }
        )
        XCTAssertEqual(config.replaces, ["RealAssembly"])
        XCTAssertEqual(config.assemblyType, .fakeAssembly)
    }

    func testReplacedAssemblyTypealias_nonFakeAssembly() throws {
        /// If someone happens to declare a `typealias ReplacedAssembly` but the assembly is *not*
        /// a `FakeAssembly`, then it will not get the default extension to provide the `ReplacedAssembly`
        let sourceFile: SourceFileSyntax = """
            class TestAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                typealias ReplacedAssembly = RealAssembly

                func assemble(container: Container) {
                    container.register(A.self) { }
                }
            }
            """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(
            config.replaces,
            [],
            "No replaced assemblies are declared"
        )
    }

    func testFakeAssembly_missingReplacedAssemblyTypealias() throws {
        let sourceFile: SourceFileSyntax = """
            class TestAssembly: FakeAssembly {
                typealias TargetResolver = TestResolver
            }
            """

        XCTAssertThrowsError(
            try assertParsesSyntaxTree(sourceFile),
            "Required typealias is missing",
            { error in
                if case AssemblyParsingError.missingReplacedAssemblyTypealias = error {
                    // Correct
                } else {
                    XCTFail("Incorrect error case")
                }
            }
        )
    }

    func testRedundantGetterName() throws {
        let sourceFile: SourceFileSyntax = """
            class TestAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                typealias ReplacedAssembly = RealAssembly

                func assemble(container: Container) {
                    // @knit alias("a")
                    container.register(A.self) { }
                }
            }
            """

        _ = try assertParsesSyntaxTree(sourceFile, assertErrorsToPrint: { errors in
            XCTAssertEqual(errors.count, 1)
            if case RegistrationParsingError.redundantGetter = errors[0] {
                // Correct
            } else {
                XCTFail("Incorrect error case")
            }
        })
    }

    func testRedundantAccessControl() throws {
        let sourceFile: SourceFileSyntax = """
            // @knit public
            class MyAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                
                func assemble(container: Container) {
                    // @knit public
                    container.register(PublicType.self) { _ in PublicType() }
                }
            }
        """

        _ = try assertParsesSyntaxTree(sourceFile, assertErrorsToPrint: { errors in
            XCTAssertEqual(errors.count, 1)
            if case RegistrationParsingError.redundantAccessControl = errors[0] {
                // Correct. Check the printed standard error
                assertStandardErrorMessage(
                    sourceFile: sourceFile,
                    error: errors.first,
                    expectedLineNumber: 6,
                    expectedColumnNumber: 13,
                    expectedMessage: "Access control matches the default and can be removed"
                )
            } else {
                XCTFail("Incorrect error case")
            }
        })
    }

    func testRedundantAccessControlDefault() throws {
        let sourceFile: SourceFileSyntax = """
            class MyAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                
                func assemble(container: Container) {
                    // @knit internal
                    container.register(PublicType.self) { _ in PublicType() }
                }
            }
        """

        _ = try assertParsesSyntaxTree(sourceFile, assertErrorsToPrint: { errors in
            XCTAssertEqual(errors.count, 1)
            if case RegistrationParsingError.redundantAccessControl = errors[0] {
                // Correct
            } else {
                XCTFail("Incorrect error case")
            }
        })
    }

    func testRedundantAccessControlImplements() throws {
        let sourceFile: SourceFileSyntax = """
            // @knit public
            class MyAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                
                func assemble(container: Container) {
                    container.register(PublicType.self) { _ in PublicType() }
                        // @knit public
                        .implements(OtherType.self)
                }
            }
        """

        _ = try assertParsesSyntaxTree(sourceFile, assertErrorsToPrint: { errors in
            XCTAssertEqual(errors.count, 1)
            if case RegistrationParsingError.redundantAccessControl = errors[0] {
                // Correct. Check the printed standard error
                assertStandardErrorMessage(
                    sourceFile: sourceFile,
                    error: errors.first,
                    expectedLineNumber: 7,
                    expectedColumnNumber: 17,
                    expectedMessage: "Access control matches the default and can be removed"
                )
            } else {
                XCTFail("Incorrect error case")
            }
        })
    }

    func testRedundantForwardedGetterName() throws {
        let sourceFile: SourceFileSyntax = """
            class TestAssembly: ModuleAssembly {
                typealias TargetResolver = TestResolver
                typealias ReplacedAssembly = RealAssembly

                func assemble(container: Container) {
                    container.register(A.self) { }
                        // @knit alias("b")
                        .implements(B.self)
                }
            }
            """

        _ = try assertParsesSyntaxTree(sourceFile, assertErrorsToPrint: { errors in
            XCTAssertEqual(errors.count, 1)
            if case RegistrationParsingError.redundantGetter = errors[0] {
                // Correct
            } else {
                XCTFail("Incorrect error case")
            }
        })
    }

    func testCustomAssemblyTags() throws {
        let sourceFile: SourceFileSyntax = """
            // @knit tag("shared")
            class FooAssembly: ModuleAssembly {
                typealias TargetResolver = Resolver
                func assemble(container: Container) {
                    // @knit tag("single")
                    container.register(A.self) { }
                }
            }
            """

        let config = try assertParsesSyntaxTree(sourceFile)
        XCTAssertEqual(config.registrations.count, 1)
        XCTAssertEqual(config.registrations[0].customTags, ["shared", "single"] )
    }

}

private func assertParsesSyntaxTree(
    _ sourceFile: SourceFileSyntax,
    assertErrorsToPrint assertErrorsCallback: (([Error]) throws -> Void)? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> Configuration {
    var errorsToPrint = [Error]()

    let parser = try AssemblyParser()

    let configuration = try parser.parseSyntaxTree(
        sourceFile,
        errorsToPrint: &errorsToPrint
    )

    if let assertErrorsCallback {
        try assertErrorsCallback(errorsToPrint)
    } else {
        XCTAssertEqual(errorsToPrint.count, 0, file: file, line: line)
    }

    return try XCTUnwrap(configuration.first)
}

private func assertStandardErrorMessage(
    sourceFile: SourceFileSyntax,
    error: Error?,
    expectedLineNumber: Int,
    expectedColumnNumber: Int,
    expectedMessage: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let locationConverter = SourceLocationConverter(fileName: "TestFile.swift", tree: sourceFile)
    let standardError = (error as? SyntaxError)?.standardErrorDescription(lineConverter: locationConverter)
    XCTAssertEqual(
        standardError,
        "TestFile.swift:\(expectedLineNumber):\(expectedColumnNumber): error: \(expectedMessage)\n",
        file: file,
        line: line
    )
}
