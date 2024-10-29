//
// Copyright © Block, Inc. All rights reserved.
//

@testable import KnitCodeGen
import XCTest

final class ConfigurationSetTests: XCTestCase {

    func testTypeSafetyOutput() {
        let configSet = ConfigurationSet(
            assemblies: [Factory.config1, Factory.config2, Factory.config3],
            externalTestingAssemblies: [],
            moduleDependencies: []
        )

        XCTAssertEqual(
            try configSet.makeTypeSafetySourceFile(),
            """
            // Generated using Knit
            // Do not edit directly!

            import Dependency1
            import Dependency2
            import Swinject

            // The correct resolution of each of these types is enforced by a matching automated unit test
            // If a type registration is missing or broken then the automated tests will fail for that PR
            /// Generated from ``Module1Assembly``
            extension Resolver {
                public func service1(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> Service1 {
                    knitUnwrap(resolve(Service1.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
                }
            }
            /// Generated from ``Module2Assembly``
            extension Resolver {
                public func callAsFunction(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> Service2 {
                    knitUnwrap(resolve(Service2.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
                }
                func argumentService(string: String, file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> ArgumentService {
                    knitUnwrap(resolve(ArgumentService.self, argument: string), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
                }
            }
            /// Generated from ``Module3Assembly``
            extension Resolver {
                public func service3(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> Service3 {
                    knitUnwrap(resolve(Service3.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
                }
            }
            """
        )
    }

    func testUnitTestOutput() {
        let configSet = ConfigurationSet(
            assemblies: [Factory.config1, Factory.config2],
            externalTestingAssemblies: [],
            moduleDependencies: []
        )

        XCTAssertEqual(
            configSet.unitTestImports().sorted.map { $0.description },
            [
                "import Dependency1",
                "import Dependency2",
                "@testable import Module1",
                "import XCTest",
            ]
        )

        XCTAssertEqual(
            try configSet.makeUnitTestSourceFile(),
            #"""
            // Generated using Knit
            // Do not edit directly!

            import Dependency1
            import Dependency2
            @testable import Module1
            import XCTest
            final class Module1RegistrationTests: XCTestCase {
                @MainActor
                func testRegistrations() {
                    // In the test target for your module, please provide a static method that creates a
                    // ModuleAssembler instance for testing.
                    let assembler = Module1Assembly.makeAssemblerForTests()
                    let resolver = assembler.resolver
                    resolver.assertTypeResolves(Service1.self)
                    resolver.assertCollectionResolves(CollectionService.self, count: 1)
                }
            }
            final class Module2RegistrationTests: XCTestCase {
                @MainActor
                func testRegistrations() {
                    // In the test target for your module, please provide a static method that creates a
                    // ModuleAssembler instance for testing.
                    let assembler = Module2Assembly.makeAssemblerForTests()
                    // In the test target for your module, please provide a static method that provides
                    // an instance of Module2RegistrationTestArguments
                    let args: Module2RegistrationTestArguments = Module2Assembly.makeArgumentsForTests()
                    let resolver = assembler.resolver
                    resolver.assertTypeResolves(Service2.self)
                    resolver.assertTypeResolved(resolver.resolve(ArgumentService.self, argument: args.argumentServiceString))
                }
            }
            struct Module2RegistrationTestArguments {
                let argumentServiceString: String
            }
            private extension Resolver {
                func assertTypeResolves<T>(
                    _ type: T.Type,
                    name: String? = nil,
                    file: StaticString = #filePath,
                    line: UInt = #line
                ) {
                    XCTAssertNotNil(
                        resolve(type, name: name),
                        """
                        The container did not resolve the type: \(type). Check that this type is registered correctly.
                        Dependency Graph:
                        \(_dependencyTree())
                        """,
                        file: file,
                        line: line
                    )
                }
                func assertTypeResolved<T>(
                    _ result: T?,
                    file: StaticString = #filePath,
                    line: UInt = #line
                ) {
                    XCTAssertNotNil(
                        result,
                        """
                        The container did not resolve the type: \(T.self). Check that this type is registered correctly.
                        Dependency Graph:
                        \(_dependencyTree())
                        """,
                        file: file,
                        line: line
                    )
                }
                @MainActor
                func assertCollectionResolves<T>(
                    _ type: T.Type,
                    count expectedCount: Int,
                    file: StaticString = #filePath,
                    line: UInt = #line
                ) {
                    let actualCount = resolveCollection(type).entries.count
                    XCTAssert(
                        actualCount >= expectedCount,
                        """
                        The resolved ServiceCollection<\(type)> did not contain the expected number of services \
                        (resolved \(actualCount), expected \(expectedCount)).
                        Make sure your assembler contains a ServiceCollector behavior.
                        """,
                        file: file,
                        line: line
                    )
                }
            }
            """#
        )
    }

    func testKnitModuleOutput() throws {
        let configSet = ConfigurationSet(
            assemblies: [Factory.config1, Factory.config2, Factory.config3],
            externalTestingAssemblies: [],
            moduleDependencies: ["ModuleA", "ModuleB"]
        )

        XCTAssertEqual(
            try configSet.makeKnitModuleSourceFile(),
            """
            // Generated using Knit
            // Do not edit directly!

            import Knit
            import ModuleA
            import ModuleB
            public enum Module1_KnitModule: KnitModule {
                public static var assemblies: [any ModuleAssembly.Type] {
                    [
                        Module1Assembly.self,
                        Module2Assembly.self,
                        Module3Assembly.self]
                }
                public static var moduleDependencies: [KnitModule.Type] {
                    [
                        ModuleA_KnitModule.self,
                        ModuleB_KnitModule.self]
                }
            }
            extension Module1Assembly: GeneratedModuleAssembly {
                public static var generatedDependencies: [any ModuleAssembly.Type] {
                    Module1_KnitModule.allAssemblies
                }
            }
            extension Module2Assembly: GeneratedModuleAssembly {
                public static var generatedDependencies: [any ModuleAssembly.Type] {
                    Module1_KnitModule.allAssemblies
                }
            }
            extension Module3Assembly: GeneratedModuleAssembly {
                public static var generatedDependencies: [any ModuleAssembly.Type] {
                    Module1_KnitModule.allAssemblies
                }
            }
            """
        )
    }

    func testAdditionalTests() throws {
        let configSet = ConfigurationSet(
            assemblies: [Factory.config1],
            externalTestingAssemblies: [Factory.config2],
            moduleDependencies: []
        )
        
        XCTAssertEqual(
            configSet.unitTestImports().sorted.map { $0.description },
            [
                "import Dependency1",
                "import Dependency2",
                "@testable import Module1",
                "import Module2",
                "import XCTest",
            ]
        )

        let additionalTests = try configSet.makeAdditionalTestsSources()
        XCTAssertEqual(additionalTests.count, 1)
        XCTAssertEqual(
            additionalTests[0].formatted().description,
            """
            final class Module2RegistrationTests: XCTestCase {
                @MainActor
                func testRegistrations() {
                    // In the test target for your module, please provide a static method that creates a
                    // ModuleAssembler instance for testing.
                    let assembler = Module1Assembly.makeAssemblerForTests()
                    let resolver = assembler.resolver
                    resolver.assertTypeResolves(Service2.self)
                }
            }
            struct Module2RegistrationTestArguments {
                let argumentServiceString: String
            }
            """
        )

    }

    func testValidateDuplicates() {

        var configSet = Factory.makeConfigSet(
            duplicateService: "DuplicateService",
            serviceName: nil,
            serviceArguments: []
        )

        XCTAssertThrowsError(
            try configSet.validateNoDuplicateRegistrations(),
            "Should throw error for duplicated registration",
            { error in
                if case let ConfigurationSetParsingError.detectedDuplicateRegistration(service: service, name: name, arguments: arguments) = error {
                    XCTAssertEqual(service, "DuplicateService")
                    XCTAssertNil(name)
                    XCTAssertEqual(arguments, [])
                } else {
                    XCTFail("Incorrect error")
                }
            }
        )

        // Test with a service name
        configSet = Factory.makeConfigSet(
            duplicateService: "DuplicateNamedService",
            serviceName: "aName",
            serviceArguments: []
        )

        XCTAssertThrowsError(
            try configSet.validateNoDuplicateRegistrations(),
            "Should throw error for duplicated registration",
            { error in
                if case let ConfigurationSetParsingError.detectedDuplicateRegistration(service: service, name: name, arguments: arguments) = error {
                    XCTAssertEqual(service, "DuplicateNamedService")
                    XCTAssertEqual(name, "aName")
                    XCTAssertEqual(arguments, [])
                } else {
                    XCTFail("Incorrect error")
                }
            }
        )

        // Test with service argument
        configSet = Factory.makeConfigSet(
            duplicateService: "DuplicateServiceArguments",
            serviceName: nil,
            serviceArguments: ["Argument"]
        )

        XCTAssertThrowsError(
            try configSet.validateNoDuplicateRegistrations(),
            "Should throw error for duplicated registration",
            { error in
                if case let ConfigurationSetParsingError.detectedDuplicateRegistration(service: service, name: name, arguments: arguments) = error {
                    XCTAssertEqual(service, "DuplicateServiceArguments")
                    XCTAssertNil(name)
                    XCTAssertEqual(arguments, ["Argument"])
                } else {
                    XCTFail("Incorrect error")
                }
            }
        )

        // No duplicates
        configSet = ConfigurationSet(
            assemblies: [
                .init(assemblyName: "TestAssembly", moduleName: "TestModule", registrations: [Registration(service: "Service")], targetResolver: "TestResolver")
            ],
            externalTestingAssemblies: [],
            moduleDependencies: []
        )
        XCTAssertNoThrow(try configSet.validateNoDuplicateRegistrations())
    }

    func testValidateDuplicates_multipleTargetResolvers() {
        // Registrations should only be compared to other registrations for the same TargetResolver
        // It is allowed to make the same registration on two different TargetResolvers

        let configSet = Factory.makeConfigSetAcrossTwoTargetResolvers(
            duplicateService: "DuplicateService",
            serviceName: nil,
            serviceArguments: []
        )

        XCTAssertNoThrow(try configSet.validateNoDuplicateRegistrations())
    }

}

private enum Factory {

    static let config1 = Configuration(
        assemblyName: "Module1Assembly",
        moduleName: "Module1",
        registrations: [
            .init(service: "Service1", accessLevel: .public)
        ],
        registrationsIntoCollections: [
            .init(service: "CollectionService")
        ],
        imports: [
            .named("Dependency1")
        ],
        targetResolver: "Resolver"
    )

    static let config2 = Configuration(
        assemblyName: "Module2Assembly",
        moduleName: "Module2",
        registrations: [
            .init(service: "Service2", accessLevel: .public, getterConfig: [.callAsFunction]),
            .init(service: "ArgumentService", accessLevel: .internal, arguments: [.init(type: "String")])

        ],
        imports: [
            .named("Dependency2")
        ],
        targetResolver: "Resolver"
    )

    static let config3 = Configuration(
        assemblyName: "Module3Assembly",
        moduleName: "Module3",
        registrations: [
            .init(service: "Service3", accessLevel: .public),
        ],
        imports: [
            .named("Dependency2")
        ],
        targetResolver: "Resolver"
    )

    static func makeConfigSet(
        duplicateService: String,
        serviceName: String?,
        serviceArguments: [String]
    ) -> ConfigurationSet {
        let config1 = Configuration(
            assemblyName: "Assembly1",
            moduleName: "Module1",
            registrations: [
                Factory.makeRegistration(
                    duplicateService: duplicateService,
                    duplicateServiceName: serviceName,
                    duplicateArguments: serviceArguments
                )
            ],
            targetResolver: "TestResolver"
        )
        let config2 = Configuration(
            assemblyName: "Assembly2",
            moduleName: "Module2",
            registrations: [
                Factory.makeRegistration(
                    duplicateService: duplicateService,
                    duplicateServiceName: serviceName,
                    duplicateArguments: serviceArguments
                )
            ],
            targetResolver: "TestResolver"
        )
        return ConfigurationSet(
            assemblies: [
                config1,
                config2,
            ], externalTestingAssemblies: [],
            moduleDependencies: []
        )
    }

    static func makeConfigSetAcrossTwoTargetResolvers(
        duplicateService: String,
        serviceName: String?,
        serviceArguments: [String]
    ) -> ConfigurationSet {
        let config1 = Configuration(
            assemblyName: "Assembly1",
            moduleName: "Module1",
            registrations: [
                Factory.makeRegistration(
                    duplicateService: duplicateService,
                    duplicateServiceName: serviceName,
                    duplicateArguments: serviceArguments
                )
            ],
            targetResolver: "TestResolver"
        )
        let config2 = Configuration(
            assemblyName: "Assembly2",
            moduleName: "Module2",
            registrations: [
                Factory.makeRegistration(
                    duplicateService: duplicateService,
                    duplicateServiceName: serviceName,
                    duplicateArguments: serviceArguments
                )
            ],
            targetResolver: "OtherTestResolver"
        )
        return ConfigurationSet(
            assemblies: [
                config1,
                config2,
            ], externalTestingAssemblies: [],
            moduleDependencies: []
        )
    }

    static func makeRegistration(
        duplicateService: String,
        duplicateServiceName: String?,
        duplicateArguments: [String]
    ) -> Registration {
        Registration(
            service: duplicateService,
            name: duplicateServiceName,
            arguments: duplicateArguments.map { .init(type: $0) }
        )
    }

}
