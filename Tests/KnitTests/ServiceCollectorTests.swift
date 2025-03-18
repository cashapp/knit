//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import Swinject
import XCTest

protocol ServiceProtocol {}

struct ServiceA: ServiceProtocol {}

struct ServiceB: ServiceProtocol {}

struct AssemblyA: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] = []

    func assemble(container: Knit.Container<Self.TargetResolver>) {
        container.registerIntoCollection(ServiceProtocol.self, factory: { _ in ServiceA() })
    }
}

struct AssemblyB: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] = []

    func assemble(container: Knit.Container<Self.TargetResolver>) {
        container.registerIntoCollection(ServiceProtocol.self, factory: { _ in ServiceB() })
    }
}

struct AssemblyC: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] = []

    func assemble(container: Knit.Container<Self.TargetResolver>) { }
}

final class CustomService: ServiceProtocol {
    var name: String

    init(name: String) {
        self.name = name
    }
}

struct HighArityService: ServiceProtocol, Equatable {
    var string: String
    var uint: UInt
    var int: Int
}

// MARK: -

final class ServiceCollectorTests: XCTestCase {

    // MARK: - Tests - registerIntoCollection

    @MainActor
    func test_registerIntoCollection() {
        let swinjectContainer = Swinject.Container()
        let container = Knit.Container<Any>._instantiateAndRegister(_swinjectContainer: swinjectContainer)
        container._unwrappedSwinjectContainer.addBehavior(ServiceCollector())

        // Register some services into a collection
        container.registerIntoCollection(ServiceProtocol.self) { _ in ServiceA() }
        container.registerIntoCollection(ServiceProtocol.self) { _ in ServiceB() }

        // Register some other services into a different collection
        container.registerIntoCollection(CustomService.self) { _ in CustomService(name: "Custom 1") }
        container.registerIntoCollection(CustomService.self) { _ in CustomService(name: "Custom 2") }

        // Resolving each collection should produce the expected services
        let serviceProtocolCollection = container._unwrappedSwinjectContainer.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(serviceProtocolCollection.entries.count, 2)
        XCTAssert(serviceProtocolCollection.entries.first is ServiceA)
        XCTAssert(serviceProtocolCollection.entries.last is ServiceB)

        let customServiceCollection = container._unwrappedSwinjectContainer.resolveCollection(CustomService.self)
        XCTAssertEqual(
            customServiceCollection.entries.map(\.name),
            ["Custom 1", "Custom 2"]
        )
    }

    @MainActor
    func test_registerIntoCollection_emptyWithBehavior() {
        let swinjectContainer = Swinject.Container()
        let container = Knit.Container<Any>._instantiateAndRegister(_swinjectContainer: swinjectContainer)
        container._unwrappedSwinjectContainer.addBehavior(ServiceCollector())

        let collection = container._unwrappedSwinjectContainer.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 0)
    }

    @MainActor
    func test_registerIntoCollection_emptyWithoutBehavior() {
        let swinjectContainer = Swinject.Container()
        let container = Knit.Container<Any>._instantiateAndRegister(_swinjectContainer: swinjectContainer)

        let collection = container._unwrappedSwinjectContainer.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 0)
    }

    /// ``ServiceCollector`` shouldn't preclude users from registering their own separate ``Array<Service>``.
    /// A conflict here would be confusing and surprising to the user.
    @MainActor
    func test_registerIntoCollection_doesntConflictWithArray() throws {
        let swinjectContainer = Swinject.Container()
        let container = Knit.Container<Any>._instantiateAndRegister(_swinjectContainer: swinjectContainer)
        container._unwrappedSwinjectContainer.addBehavior(ServiceCollector())

        // Register A into a collection
        container.registerIntoCollection(ServiceProtocol.self) { _ in ServiceA() }

        // Register B as an array
        container.register([ServiceProtocol].self) { _ in [ServiceB()] }

        // Resolving the collection should produce A
        let collection = container._unwrappedSwinjectContainer.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 1)
        XCTAssert(collection.entries.first is ServiceA)

        // Resolving the array should produce B
        let array = try XCTUnwrap(container._unwrappedSwinjectContainer.resolve([ServiceProtocol].self))
        XCTAssertEqual(array.count, 1)
        XCTAssert(array.first is ServiceB)
    }

    @MainActor
    func test_registerIntoCollection_doesntImplicitlyAggregateInstances() throws {
        let swinjectContainer = Swinject.Container()
        let container = Knit.Container<Any>._instantiateAndRegister(_swinjectContainer: swinjectContainer)
        container._unwrappedSwinjectContainer.addBehavior(ServiceCollector())

        // Register A and B into a collection
        _ = container.registerIntoCollection(ServiceProtocol.self) { _ in ServiceA() }
        _ = container.registerIntoCollection(ServiceProtocol.self) { _ in ServiceB() }

        // Register B individually
        _ = container.register(ServiceProtocol.self) { _ in ServiceB() }

        // Resolving the collection should produce A and B
        let collection = container._unwrappedSwinjectContainer.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 2)
        XCTAssert(collection.entries.first is ServiceA)
        XCTAssert(collection.entries.last is ServiceB)

        // Resolving the service individually should produce B
        XCTAssert(container._unwrappedSwinjectContainer.resolve(ServiceProtocol.self) is ServiceB)
    }

    @MainActor
    func test_registerIntoCollection_allowsDuplicates() {
        let swinjectContainer = Swinject.Container()
        let container = Knit.Container<Any>._instantiateAndRegister(_swinjectContainer: swinjectContainer)
        container._unwrappedSwinjectContainer.addBehavior(ServiceCollector())

        // Register some duplicate services
        _ = container.registerIntoCollection(ServiceProtocol.self) { _ in CustomService(name: "Dry Cleaning") }
        _ = container.registerIntoCollection(ServiceProtocol.self) { _ in CustomService(name: "Car Repair") }
        _ = container.registerIntoCollection(ServiceProtocol.self) { _ in CustomService(name: "Car Repair") }

        // Resolving the collection should produce all services
        let collection = container._unwrappedSwinjectContainer.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(
            collection.entries.compactMap { ($0 as? CustomService)?.name },
            ["Dry Cleaning", "Car Repair", "Car Repair"]
        )
    }

    // MARK: - Tests - Object Scopes

    @MainActor
    func test_registerIntoCollection_supportsTransientScopedObjects() throws {
        let swinjectContainer = Swinject.Container()
        let container = Knit.Container<Any>._instantiateAndRegister(_swinjectContainer: swinjectContainer)
        container._unwrappedSwinjectContainer.addBehavior(ServiceCollector())

        // Register a service with the `transient` scope.
        // It should be recreated each time the ServiceCollection is resolved.
        container
            .registerIntoCollection(CustomService.self) { _ in CustomService(name: "service") }
            .inObjectScope(.transient)

        let collection1 = container._unwrappedSwinjectContainer.resolveCollection(CustomService.self)
        let collection2 = container._unwrappedSwinjectContainer.resolveCollection(CustomService.self)

        let instance1 = try XCTUnwrap(collection1.entries.first)
        let instance2 = try XCTUnwrap(collection2.entries.first)

        XCTAssert(instance1 !== instance2)
    }

    @MainActor
    func test_registerIntoCollection_supportsContainerScopedObjects() throws {
        let swinjectContainer = Swinject.Container()
        let container = Knit.Container<Any>._instantiateAndRegister(_swinjectContainer: swinjectContainer)
        container._unwrappedSwinjectContainer.addBehavior(ServiceCollector())

        // Register a service with the `container` scope.
        // The same instance should be shared, even if the collection is resolved many times.
        container
            .registerIntoCollection(CustomService.self) { _ in CustomService(name: "service") }
            .inObjectScope(.container)

        let collection1 = container._unwrappedSwinjectContainer.resolveCollection(CustomService.self)
        let collection2 = container._unwrappedSwinjectContainer.resolveCollection(CustomService.self)

        let instance1 = try XCTUnwrap(collection1.entries.first)
        let instance2 = try XCTUnwrap(collection2.entries.first)

        XCTAssert(instance1 === instance2)
    }

    @MainActor
    func test_registerIntoCollection_supportsWeakScopedObjects() throws {
        let swinjectContainer = Swinject.Container()
        let container = Knit.Container<Any>._instantiateAndRegister(_swinjectContainer: swinjectContainer)
        container._unwrappedSwinjectContainer.addBehavior(ServiceCollector())

        // Register a service with the `weak` scope.
        // The same instance should be shared while the instance is alive.
        // We track the number of times the factory is invoked so we know when an instance was created vs reused.
        var factoryCallCount = 0
        container
            .registerIntoCollection(CustomService.self) { _ in
                factoryCallCount += 1
                return CustomService(name: "service")
            }
            .inObjectScope(.weak)

        // Resolve the initial instance
        var instance1: CustomService? = try XCTUnwrap(container._unwrappedSwinjectContainer.resolveCollection(CustomService.self).entries.first)
        XCTAssertEqual(factoryCallCount, 1)

        // Resolving again shouldn't increase `factoryCallCount` since `instance1` is still retained.
        var instance2: CustomService? = try XCTUnwrap(container._unwrappedSwinjectContainer.resolveCollection(CustomService.self).entries.first)
        XCTAssertEqual(factoryCallCount, 1)
        XCTAssert(instance2 === instance1)

        // Release our instances and resolve again. This time a new instance should be created.
        instance1 = nil
        instance2 = nil
        _ = container._unwrappedSwinjectContainer.resolveCollection(CustomService.self)
        XCTAssertEqual(factoryCallCount, 2)
    }

    @MainActor
    func test_parentChildContainersWithAssemblers() throws {
        let parent = try ModuleAssembler(
            _modules: [AssemblyA()],
            preAssemble: { container in
                Knit.Container<TestResolver>._instantiateAndRegister(_swinjectContainer: container)
            },
            autoConfigureContainers: false
        )
        let child = try ModuleAssembler(
            parent: parent,
            _modules: [AssemblyB()],
            preAssemble: { container in
                Knit.Container<TestResolver>._instantiateAndRegister(_swinjectContainer: container)
            },
            autoConfigureContainers: false
        )

        // When resolving from the parent resolver we only get services from AssemblyA
        XCTAssertEqual(
            parent.resolver.resolveCollection(ServiceProtocol.self).entries.count,
            1
        )

        // When resolving from the child resolver we get both
        XCTAssertEqual(
            child.resolver.resolveCollection(ServiceProtocol.self).allEntries.count,
            2
        )
        
        // It's possible to distinguish the items that were registered in the parent
        XCTAssertEqual(
            child.resolver.resolveCollection(ServiceProtocol.self).entries.count,
            1
        )
        
    }

    @MainActor
    func test_childWithEmptyParent() throws {
        let parent = try ModuleAssembler(
            _modules: [AssemblyC()],
            preAssemble: { container in
                Knit.Container<TestResolver>._instantiateAndRegister(_swinjectContainer: container)
            },
            autoConfigureContainers: false
        )
        let child = try ModuleAssembler(
            parent: parent,
            _modules: [AssemblyB()],
            preAssemble: { container in
                Knit.Container<TestResolver>._instantiateAndRegister(_swinjectContainer: container)
            },
            autoConfigureContainers: false
        )

        // Parent has no services registered
        XCTAssertEqual(
            parent.resolver.resolveCollection(ServiceProtocol.self).entries.count,
            0
        )

        XCTAssertEqual(
            child.resolver.resolveCollection(ServiceProtocol.self).entries.count,
            1
        )
    }

    @MainActor
    func test_emptyChildWithParent() throws {
        let parent = try ModuleAssembler(_modules: [AssemblyB()])
        let child = try ModuleAssembler(parent: parent, _modules: [AssemblyC()])

        // The parent itself has no services so they come from the child
        XCTAssertEqual(
            child.resolver.resolveCollection(ServiceProtocol.self).entries.count,
            1
        )
        
        // The child can access the parent services
        XCTAssertEqual(
            child.resolver.resolveCollection(ServiceProtocol.self).allEntries.count,
            1
        )
    }

    @MainActor
    func test_grandparentRelationship() throws {
        let grandParent = try ModuleAssembler(
            _modules: [AssemblyA()],
            preAssemble: { container in
                Knit.Container<TestResolver>._instantiateAndRegister(_swinjectContainer: container)
            },
            autoConfigureContainers: false
        )
        let parent = try ModuleAssembler(
            parent: grandParent,
            _modules: [AssemblyC()],
            preAssemble: { container in
                Knit.Container<TestResolver>._instantiateAndRegister(_swinjectContainer: container)
            },
            autoConfigureContainers: false
        )
        let child = try ModuleAssembler(
            parent: parent,
            _modules: [AssemblyB()],
            preAssemble: { container in
                Knit.Container<TestResolver>._instantiateAndRegister(_swinjectContainer: container)
            },
            autoConfigureContainers: false
        )

        // The child has access to all services
        XCTAssertEqual(
            child.resolver.resolveCollection(ServiceProtocol.self).allEntries.count,
            2
        )

        // The parent has access to grandparent services
        XCTAssertEqual(
            parent.resolver.resolveCollection(ServiceProtocol.self).allEntries.count,
            1
        )

        // 1 service is registered directly into the child
        XCTAssertEqual(
            child.resolver.resolveCollection(ServiceProtocol.self).entries.count,
            1
        )
    }
}
