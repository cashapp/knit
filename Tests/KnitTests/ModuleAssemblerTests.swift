//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
@testable import Swinject
import XCTest

final class ModuleAssemblerTests: XCTestCase {

    @MainActor
    func test_auto_assembler() {
        let resolver = ModuleAssembler([Assembly1()]).resolver
        XCTAssertNotNil(resolver.resolve(Service1.self))
    }

    @MainActor
    func test_non_auto_assembler() {
        let resolver = ModuleAssembler([
            Assembly3(),
            Assembly1(),
        ]).resolver
        XCTAssertNotNil(resolver.resolve(Service1.self))
        XCTAssertNotNil(resolver.resolve(Service3.self))
    }

    @MainActor
    func test_registered_modules() {
        let assembler = ModuleAssembler([Assembly1()])
        XCTAssertTrue(assembler.registeredModules.contains(where: {$0 == Assembly1.self}))
        XCTAssertTrue(assembler.registeredModules.contains(where: {$0 == Assembly2.self}))
        XCTAssertFalse(assembler.registeredModules.contains(where: {$0 == Assembly3.self}))
    }

    @MainActor
    func test_parent_assembler() {
        // Put some modules in the parent and some in the child.
        let parent = ModuleAssembler([Assembly1()])
        let child = ModuleAssembler(parent: parent, [Assembly3()])
        XCTAssertTrue(child.isRegistered(Assembly1.self))
        XCTAssertTrue(child.isRegistered(Assembly3.self))
        XCTAssertTrue(child.isRegistered(Assembly2.self))

        XCTAssertFalse(child.registeredModules.contains(where: {$0 == Assembly1.self}))

        XCTAssertNotNil(child.resolver.resolve(Service1.self))
        XCTAssertNil(parent.resolver.resolve(Service3.self))
    }

    @MainActor
    func test_abstractAssemblyValidation() {
        XCTAssertThrowsError(
            try ModuleAssembler(
                _modules: [ Assembly4() ],
                overrideBehavior: .init(allowDefaultOverrides: true, useAbstractPlaceholders: false)
            ),
            "Should throw an error for missing concrete registration to fulfill abstract registration",
            { error in
                guard let abstractRegistrationErrors = error as? Container.AbstractRegistrationErrors else {
                    XCTFail("Incorrect error type \(error)")
                    return
                }
                XCTAssertEqual(abstractRegistrationErrors.errors.count, 2)

                // Abstract registration one
                XCTAssertEqual(abstractRegistrationErrors.errors.first?.serviceType, "Assembly5Protocol")
                XCTAssertNil(abstractRegistrationErrors.errors.first?.name)

                // Abstract registration two
                XCTAssertEqual(abstractRegistrationErrors.errors.last?.serviceType, "Assembly5Protocol")
                XCTAssertEqual(abstractRegistrationErrors.errors.last?.name, "testName")
            }
        )
    }

    @MainActor
    func test_abstractAssemblyPlaceholders() throws {
        // No error is thrown as the graph is using abstract placeholders
        let assembler = try ModuleAssembler(
            _modules: [ Assembly4() ],
            overrideBehavior: .init(allowDefaultOverrides: true, useAbstractPlaceholders: true)
        )

        var services = assembler._container.services.filter { (key, value) in
            // Filter out registrations for `AbstractRegistrationContainer` and `DependencyTree`
            return key.serviceType != Container.AbstractRegistrationContainer.self &&
            key.serviceType != DependencyTree.self
        }
        XCTAssertEqual(services.count, 2)
        
        XCTAssertNotNil(services.removeValue(forKey: .init(
            serviceType: Assembly5Protocol.self,
            argumentsType: (Resolver).self,
            name: nil
        )), "Service entry for Assembly5Protocol without name should exist")
        XCTAssertEqual(services.count, 1)

        XCTAssertNotNil(services.removeValue(forKey: .init(
            serviceType: Assembly5Protocol.self,
            argumentsType: (Resolver).self,
            name: "testName"
        )), "Service entry for Assembly5Protocol with name should exist")
        
        // No more registrations left
        XCTAssertEqual(services.count, 0)
    }

}

// Assembly1 depends on Assembly2 and registers Service1
private struct Assembly1: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] {
        return [
            Assembly2.self
        ]
    }

    func assemble(container: Container) {
        container.register(Service1.self) { Service1(service2: $0.resolve(Service2.self)!) }
    }
}

// Assembly2 has no dependencies and registers Service2
private struct Assembly2: AutoInitModuleAssembly {

    static var dependencies: [any ModuleAssembly.Type] {
        return []
    }

    func assemble(container: Container) {
        container.register(Service2.self) { _ in Service2() }
    }
}

// Assembly3 depends on Assembly1 and registers Service3
private struct Assembly3: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] {
        return [Assembly1.self]
    }

    func assemble(container: Container) {
        container.register(Service3.self) { _ in Service3()}
    }
}

// Service1 depends on Service2
private struct Service1 {

    let service2: Service2

    init(service2: Service2) {
        self.service2 = service2
    }

}

private struct Service2 {}
private struct Service3 {}

// MARK: - AbstractAssembly

private struct Assembly4: AutoInitModuleAssembly {

    func assemble(container: Swinject.Container) {
        // None
    }

    static var dependencies: [any ModuleAssembly.Type] {
        [
            AbstractAssembly5.self,
            Assembly5.self,
        ]
    }
}

private struct AbstractAssembly5: AbstractAssembly {
    
    static var dependencies: [any ModuleAssembly.Type] {
        []
    }

    func assemble(container: Swinject.Container) {
        container.registerAbstract(Assembly5Protocol.self)
        container.registerAbstract(Assembly5Protocol.self, name: "testName")
    }

}

private protocol Assembly5Protocol { }

private struct Assembly5: AutoInitModuleAssembly {
    
    static var dependencies: [any ModuleAssembly.Type] { [] }

    func assemble(container: Swinject.Container) {
        // Missing a concrete registration for `Assembly5Protocol`
    }
    
    static var replaces: [any ModuleAssembly.Type] {
        [AbstractAssembly5.self]
    }

}
