//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import XCTest

final class AbstractRegistrationTests: XCTestCase {

    func testMissingRegistration() {
        let container = Container()
        let abstractRegistrations = container.registerAbstractContainer()
        container.registerAbstract(String.self)
        container.registerAbstract(String.self, name: "test")
        container.registerAbstract(Optional<Int>.self)

        XCTAssertThrowsError(try abstractRegistrations.validate()) { error in
            XCTAssertEqual(
                error.localizedDescription,
                """
                Unsatisfied abstract registration. Service: String, File: KnitTests/AbstractRegistrationTests.swift
                Unsatisfied abstract registration. Service: String, File: KnitTests/AbstractRegistrationTests.swift, Name: test
                Unsatisfied abstract registration. Service: Optional<Int>, File: KnitTests/AbstractRegistrationTests.swift
                """
            )
        }
    }

    func testFilledRegistrations() {
        let container = Container()
        let abstractRegistrations = container.registerAbstractContainer()
        container.registerAbstract(String.self)
        container.register(String.self) { _ in "Test" }

        // Abstract registrations of Optional types are handled differently so test that as well
        container.registerAbstract(Optional<Int>.self)
        container.register(Optional<Int>.self) { _ in 1 }

        XCTAssertNoThrow(try abstractRegistrations.validate())
        XCTAssertEqual(container.resolve(String.self), "Test")
        XCTAssertEqual(container.resolve(Optional<Int>.self), 1)
    }

    func testNamedRegistrations() {
        let container = Container()
        let abstractRegistrations = container.registerAbstractContainer()
        container.registerAbstract(String.self)
        container.registerAbstract(String.self, name: "test")

        container.register(String.self) { _ in "Test" }
        XCTAssertThrowsError(try abstractRegistrations.validate())

        container.register(String.self, name: "wrong") { _ in "Test" }
        XCTAssertThrowsError(try abstractRegistrations.validate())

        container.register(String.self, name: "test") { _ in "Test" }
        XCTAssertNoThrow(try abstractRegistrations.validate())
    }

    func testPreRegistered() {
        let container = Container()
        let abstractRegistrations = container.registerAbstractContainer()
        container.register(String.self) { _ in "Test" }
        container.registerAbstract(String.self)
        XCTAssertNoThrow(try abstractRegistrations.validate())
    }

    func testAbstractErrorFormatting() throws {
        let builder = try DependencyBuilder(modules: [Assembly1()])
        let error = Container.AbstractRegistrationError(serviceType: "String", file: "Assembly2.swift", name: nil)
        let errors = Container.AbstractRegistrationErrors(errors: [error])
        let formatter = DefaultModuleAssemblerErrorFormatter()
        let result = formatter.format(error: errors, dependencyTree: builder.dependencyTree)
        XCTAssertEqual(
            result,
            """
            Unsatisfied abstract registration. Service: String, File: Assembly2.swift
            Dependency path: Assembly1 -> Assembly2
            Error creating ModuleAssembler. Please make sure all necessary assemblies are provided.
            """
        )
    }

    @MainActor
    func testOptionalAbstractRegistrations() {
        let assembler = ModuleAssembler([Assembly3()])
        let string = assembler.resolver.resolve(String?.self) ?? nil
        XCTAssertNil(string)

        let int = assembler.resolver.resolve(Optional<Int>.self) ?? nil
        XCTAssertNil(int)
    }

}

private struct Assembly1: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [ Assembly2.self] }
    func assemble(container: Container) {}
}

private struct Assembly2: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) {
        container.registerAbstract(String.self)
    }
}

private struct Assembly3: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) {
        container.registerAbstract(Optional<String>.self)
        container.registerAbstract(Int?.self)
    }
}
