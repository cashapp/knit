//
// Copyright © Block, Inc. All rights reserved.
//

import Combine
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

    @MainActor
    func testAdditionalAbstractRegistration() {
        let assembler = ModuleAssembler([Assembly4()])
        _ = assembler.resolver.resolve(AnyPublisher<String?, Never>.self)
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

private struct Assembly4: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) {
        // Custom handling for AnyPublisher abstract registrations is defined below
        container.registerAbstract(AnyPublisher<String?, Never>.self)
    }
}

// Example of an abstract registration for a type not supported by Knit
private struct AnyPublisherAbstractRegistration<UnwrappedServiceType>: AbstractRegistration {
    typealias ServiceType = AnyPublisher<UnwrappedServiceType?, Never>

    let name: String?
    let file: String
    let concurrency: ConcurrencyAttribute

    var serviceDescription: String { String(describing: ServiceType.self) }

    func registerPlaceholder(
        container: Swinject.Container,
        errorFormatter: any Knit.ModuleAssemblerErrorFormatter,
        dependencyTree: Knit.DependencyTree
    ) {
        container.register(ServiceType.self, name: name) { _ in
            Just(nil).eraseToAnyPublisher()
        }
    }
}

private extension Container {

    // The new abstract registration type requires an additional registerAbstract function with a more explicit type
    func registerAbstract<Service>(
        _ serviceType: AnyPublisher<Service?, Never>.Type,
        name: String? = nil,
        concurrency: ConcurrencyAttribute = .nonisolated,
        file: String = #fileID
    ) {
        let registration = AnyPublisherAbstractRegistration<Service>(
            name: name,
            file: file,
            concurrency: concurrency
        )
        addAbstractRegistration(registration)
    }
}
