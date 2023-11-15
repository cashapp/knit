//  Created by Alexander skorulis on 8/8/2023.

@testable import KnitCodeGen
import XCTest

final class ConfigurationSetTests: XCTestCase {

    func testTypeSafetyOutput() {
        let configSet = ConfigurationSet(assemblies: [Factory.config1, Factory.config2, Factory.config3])

        XCTAssertEqual(
            try configSet.makeTypeSafetySourceFile(),
            """
            // Generated using Knit
            // Do not edit directly!

            import Swinject
            import Dependency1
            import Dependency2

            // The correct resolution of each of these types is enforced by a matching automated unit test
            // If a type registration is missing or broken then the automated tests will fail for that PR
            // Generated from Module1Assembly
            extension Resolver {
                public func service1() -> Service1 {
                    self.resolve(Service1.self)!
                }
            }
            // Generated from Module2Assembly
            extension Resolver {
                func callAsFunction() -> Service2 {
                    self.resolve(Service2.self)!
                }
                func argumentService(string: String) -> ArgumentService {
                    self.resolve(ArgumentService.self, argument: string)!
                }
            }
            // Generated from Module3Assembly
            extension Resolver {
                public func service3() -> Service3 {
                    self.resolve(Service3.self)!
                }
            }
            """
        )
    }

    func testUnitTestOutput() {
        let configSet = ConfigurationSet(assemblies: [Factory.config1, Factory.config2])

        XCTAssertEqual(
            try configSet.makeUnitTestSourceFile(),
            #"""
            // Generated using Knit
            // Do not edit directly!

            @testable import Module1
            import XCTest
            import Dependency1
            import Dependency2
            final class Module1RegistrationTests: XCTestCase {
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
                        "The container did not resolve the type: \(type). Check that this type is registered correctly.",
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
                        "The container did not resolve the type: \(T.self). Check that this type is registered correctly.",
                        file: file,
                        line: line
                    )
                }
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

}

private enum Factory {

    static let config1 = Configuration(
        name: "Module1",
        registrations: [
            .init(service: "Service1", accessLevel: .public)
        ],
        registrationsIntoCollections: [
            .init(service: "CollectionService")
        ],
        imports: [
            .init(moduleName: "Dependency1")
        ],
        targetResolver: "Resolver"
    )

    static let config2 = Configuration(
        name: "Module2",
        registrations: [
            .init(service: "Service2", accessLevel: .internal, getterConfig: [.callAsFunction]),
            .init(service: "ArgumentService", accessLevel: .internal, arguments: [.init(type: "String")])

        ],
        registrationsIntoCollections: [],
        imports: [
            .init(moduleName: "Dependency2")
        ],
        targetResolver: "Resolver"
    )

    static let config3 = Configuration(
        name: "Module3",
        registrations: [
            .init(service: "Service3", accessLevel: .public),
        ],
        registrationsIntoCollections: [],
        imports: [
            .init(moduleName: "Dependency2")
        ],
        targetResolver: "Resolver"
    )
}
