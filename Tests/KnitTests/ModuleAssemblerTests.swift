//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
@testable import Swinject
import XCTest

final class ModuleAssemblerTests: XCTestCase {

    @MainActor
    func test_auto_assembler() throws {
        let resolver = try ModuleAssembler(
            _modules: [Assembly1()],
            preAssemble: { container in
                Knit.Container<TestResolver>._instantiateAndRegister(_swinjectContainer: container)
            }
        ).resolver
        XCTAssertNotNil(resolver.resolve(Service1.self))
    }

    @MainActor
    func test_non_auto_assembler() throws {
        let resolver = try ModuleAssembler(
            _modules: [
                Assembly3(),
                Assembly1(),
            ],
            preAssemble: { container in
                Knit.Container<TestResolver>._instantiateAndRegister(_swinjectContainer: container)
            }
        ).resolver
        XCTAssertNotNil(resolver.resolve(Service1.self))
        XCTAssertNotNil(resolver.resolve(Service3.self))
    }

    @MainActor
    func test_registered_modules() throws {
        let assembler = try ModuleAssembler(
            _modules: [Assembly1()],
            preAssemble: {
                Knit.Container<TestResolver>._instantiateAndRegister(_swinjectContainer: $0)
            }
        )
        XCTAssertTrue(assembler.registeredModules.contains(where: {$0 == Assembly1.self}))
        XCTAssertTrue(assembler.registeredModules.contains(where: {$0 == Assembly2.self}))
        XCTAssertFalse(assembler.registeredModules.contains(where: {$0 == Assembly3.self}))
    }

    @MainActor
    func test_parent_assembler() throws {
        // Put some modules in the parent and some in the child.
        let parent = try ModuleAssembler(
            _modules: [Assembly1()],
            preAssemble: { container in
                Knit.Container<TestResolver>._instantiateAndRegister(_swinjectContainer: container)
            }
        )
        let child = try ModuleAssembler.testing(parent: parent, [Assembly3()])
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
                overrideBehavior: .init(allowDefaultOverrides: true, useAbstractPlaceholders: false), 
                preAssemble: {
                    Knit.Container<TestResolver>._instantiateAndRegister(_swinjectContainer: $0)
                }
            ),
            "Should throw an error for missing concrete registration to fulfill abstract registration",
            { error in
                guard let abstractRegistrationErrors = error as? AbstractRegistrationErrors else {
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
            overrideBehavior: .init(allowDefaultOverrides: true, useAbstractPlaceholders: true), 
            preAssemble: {
                Knit.Container<TestResolver>._instantiateAndRegister(_swinjectContainer: $0)
            }
        )

        var services = assembler._swinjectContainer.services.filter { (key, value) in
            // Filter out registrations for `AbstractRegistrationContainer` and `DependencyTree`
            return key.serviceType != Container.AbstractRegistrationContainer.self &&
            key.serviceType != DependencyTree.self
        }
        XCTAssertEqual(services.count, 3)

        XCTAssertNotNil(services.removeValue(forKey: .init(
            serviceType: Assembly5Protocol.self,
            argumentsType: (Swinject.Resolver).self,
            name: nil
        )), "Service entry for Assembly5Protocol without name should exist")
        XCTAssertEqual(services.count, 2)

        XCTAssertNotNil(services.removeValue(forKey: .init(
            serviceType: Assembly5Protocol.self,
            argumentsType: (Swinject.Resolver).self,
            name: "testName"
        )), "Service entry for Assembly5Protocol with name should exist")
        
        // The last registration is for the Knit container
        XCTAssertEqual(services.count, 1)
    }

}

// Assembly1 depends on Assembly2 and registers Service1
private struct Assembly1: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] {
        return [
            Assembly2.self
        ]
    }

    func assemble(container: Knit.Container<Self.TargetResolver>) {
        container.register(
            Service1.self, 
            factory: { resolver in
                Service1(service2: resolver.service2())
            }
        )
    }
}

// Assembly2 has no dependencies and registers Service2
private struct Assembly2: AutoInitModuleAssembly {

    static var dependencies: [any ModuleAssembly.Type] {
        return []
    }

    func assemble(container: Knit.Container<Self.TargetResolver>) {
        container.register(
            Service2.self,
            factory: { _ in
                Service2()
            }
        )
    }
}

// Assembly3 depends on Assembly1 and registers Service3
private struct Assembly3: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] {
        return [Assembly1.self]
    }

    func assemble(container: Knit.Container<Self.TargetResolver>) {
        container.register(Service3.self, factory: { _ in Service3() })
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

    func assemble(container: Knit.Container<Self.TargetResolver>) {
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

    func assemble(container: Knit.Container<Self.TargetResolver>) {
        container.registerAbstract(Assembly5Protocol.self)
        container.registerAbstract(Assembly5Protocol.self, name: "testName")
    }

}

private protocol Assembly5Protocol { }

private struct Assembly5: AutoInitModuleAssembly {
    
    static var dependencies: [any ModuleAssembly.Type] { [] }

    func assemble(container: Knit.Container<Self.TargetResolver>) {
        // Missing a concrete registration for `Assembly5Protocol`
    }
    
    static var replaces: [any ModuleAssembly.Type] {
        [AbstractAssembly5.self]
    }

}

private extension TestResolver {

    func service2() -> Service2 {
        unsafeResolver.resolve(Service2.self)!
    }

}
