//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import Swinject
import XCTest

private protocol ParentResolver: Knit.Resolver {}
private protocol ChildResolver: ParentResolver {}
private protocol GrandChildResolver: ChildResolver {}

extension Knit.Container: ParentResolver, ChildResolver, GrandChildResolver {}

private protocol ServiceProtocol {}

private struct ServiceA: ServiceProtocol {}

private struct ServiceB: ServiceProtocol {}

private struct AssemblyA: AutoInitModuleAssembly {
    typealias TargetResolver = ParentResolver

    static var dependencies: [any ModuleAssembly.Type] = []

    func assemble(container: Knit.Container<Self.TargetResolver>) {
        container.registerIntoCollection(ServiceProtocol.self, factory: { _ in ServiceA() })
    }
}

private struct AssemblyB: AutoInitModuleAssembly {
    typealias TargetResolver = ChildResolver

    static var dependencies: [any ModuleAssembly.Type] = []

    func assemble(container: Knit.Container<Self.TargetResolver>) {
        container.registerIntoCollection(ServiceProtocol.self, factory: { _ in ServiceB() })
    }
}

private struct AssemblyC: AutoInitModuleAssembly {
    typealias TargetResolver = ParentResolver

    static var dependencies: [any ModuleAssembly.Type] = []

    func assemble(container: Knit.Container<Self.TargetResolver>) { }
}

private struct AssemblyD: AutoInitModuleAssembly {
    typealias TargetResolver = ChildResolver

    static var dependencies: [any ModuleAssembly.Type] = []

    func assemble(container: Knit.Container<Self.TargetResolver>) { }
}

private struct AssemblyE: AutoInitModuleAssembly {
    typealias TargetResolver = GrandChildResolver

    static var dependencies: [any ModuleAssembly.Type] = []

    func assemble(container: Knit.Container<Self.TargetResolver>) {
        container.registerIntoCollection(ServiceProtocol.self, factory: { _ in ServiceB() })
    }
}

private final class CustomService: ServiceProtocol {
    var name: String

    init(name: String) {
        self.name = name
    }
}

private struct HighArityService: ServiceProtocol, Equatable {
    var string: String
    var uint: UInt
    var int: Int
}

// MARK: -

final class ServiceCollectorTests: XCTestCase {

    // MARK: - Tests - registerIntoCollection

    @MainActor
    func test_registerIntoCollection() {
        let swinjectContainer = SwinjectContainer()
        let container = ContainerManager(swinjectContainer: swinjectContainer).register(Any.self)
        container._unwrappedSwinjectContainer().addBehavior(ServiceCollector())

        // Register some services into a collection
        container.registerIntoCollection(ServiceProtocol.self) { _ in ServiceA() }
        container.registerIntoCollection(ServiceProtocol.self) { _ in ServiceB() }

        // Register some other services into a different collection
        container.registerIntoCollection(CustomService.self) { _ in CustomService(name: "Custom 1") }
        container.registerIntoCollection(CustomService.self) { _ in CustomService(name: "Custom 2") }

        // Resolving each collection should produce the expected services
        let serviceProtocolCollection = container.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(serviceProtocolCollection.entries.count, 2)
        XCTAssert(serviceProtocolCollection.entries.first is ServiceA)
        XCTAssert(serviceProtocolCollection.entries.last is ServiceB)

        let customServiceCollection = container.resolveCollection(CustomService.self)
        XCTAssertEqual(
            customServiceCollection.entries.map(\.name),
            ["Custom 1", "Custom 2"]
        )
    }

    @MainActor
    func test_registerIntoCollection_emptyWithBehavior() {
        let swinjectContainer = SwinjectContainer()
        let container = ContainerManager(swinjectContainer: swinjectContainer).register(Any.self)
        container._unwrappedSwinjectContainer().addBehavior(ServiceCollector())

        let collection = container.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 0)
    }

    @MainActor
    func test_registerIntoCollection_emptyWithoutBehavior() {
        let swinjectContainer = SwinjectContainer()
        let container = ContainerManager(swinjectContainer: swinjectContainer).register(Any.self)

        let collection = container.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 0)
    }

    /// ``ServiceCollector`` shouldn't preclude users from registering their own separate ``Array<Service>``.
    /// A conflict here would be confusing and surprising to the user.
    @MainActor
    func test_registerIntoCollection_doesntConflictWithArray() throws {
        let swinjectContainer = SwinjectContainer()
        let container = ContainerManager(swinjectContainer: swinjectContainer).register(Any.self)
        container._unwrappedSwinjectContainer().addBehavior(ServiceCollector())

        // Register A into a collection
        container.registerIntoCollection(ServiceProtocol.self) { _ in ServiceA() }

        // Register B as an array
        container.register([ServiceProtocol].self) { _ in [ServiceB()] }

        // Resolving the collection should produce A
        let collection = container.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 1)
        XCTAssert(collection.entries.first is ServiceA)

        // Resolving the array should produce B
        let array = try XCTUnwrap(container._unwrappedSwinjectContainer().resolve([ServiceProtocol].self))
        XCTAssertEqual(array.count, 1)
        XCTAssert(array.first is ServiceB)
    }

    @MainActor
    func test_registerIntoCollection_doesntImplicitlyAggregateInstances() throws {
        let swinjectContainer = SwinjectContainer()
        let container = ContainerManager(swinjectContainer: swinjectContainer).register(Any.self)
        container._unwrappedSwinjectContainer().addBehavior(ServiceCollector())

        // Register A and B into a collection
        _ = container.registerIntoCollection(ServiceProtocol.self) { _ in ServiceA() }
        _ = container.registerIntoCollection(ServiceProtocol.self) { _ in ServiceB() }

        // Register B individually
        _ = container.register(ServiceProtocol.self) { _ in ServiceB() }

        // Resolving the collection should produce A and B
        let collection = container.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 2)
        XCTAssert(collection.entries.first is ServiceA)
        XCTAssert(collection.entries.last is ServiceB)

        // Resolving the service individually should produce B
        XCTAssert(container._unwrappedSwinjectContainer().resolve(ServiceProtocol.self) is ServiceB)
    }

    @MainActor
    func test_registerIntoCollection_allowsDuplicates() {
        let swinjectContainer = SwinjectContainer()
        let container = ContainerManager(swinjectContainer: swinjectContainer).register(Any.self)
        container._unwrappedSwinjectContainer().addBehavior(ServiceCollector())

        // Register some duplicate services
        _ = container.registerIntoCollection(ServiceProtocol.self) { _ in CustomService(name: "Dry Cleaning") }
        _ = container.registerIntoCollection(ServiceProtocol.self) { _ in CustomService(name: "Car Repair") }
        _ = container.registerIntoCollection(ServiceProtocol.self) { _ in CustomService(name: "Car Repair") }

        // Resolving the collection should produce all services
        let collection = container.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(
            collection.entries.compactMap { ($0 as? CustomService)?.name },
            ["Dry Cleaning", "Car Repair", "Car Repair"]
        )
    }

    // MARK: - Tests - Object Scopes

    @MainActor
    func test_registerIntoCollection_supportsTransientScopedObjects() throws {
        let swinjectContainer = SwinjectContainer()
        let container = ContainerManager(swinjectContainer: swinjectContainer).register(Any.self)
        container._unwrappedSwinjectContainer().addBehavior(ServiceCollector())

        // Register a service with the `transient` scope.
        // It should be recreated each time the ServiceCollection is resolved.
        container
            .registerIntoCollection(CustomService.self) { _ in CustomService(name: "service") }
            .inObjectScope(.transient)

        let collection1 = container.resolveCollection(CustomService.self)
        let collection2 = container.resolveCollection(CustomService.self)

        let instance1 = try XCTUnwrap(collection1.entries.first)
        let instance2 = try XCTUnwrap(collection2.entries.first)

        XCTAssert(instance1 !== instance2)
    }

    @MainActor
    func test_registerIntoCollection_supportsContainerScopedObjects() throws {
        let swinjectContainer = SwinjectContainer()
        let container = ContainerManager(swinjectContainer: swinjectContainer).register(Any.self)
        container._unwrappedSwinjectContainer().addBehavior(ServiceCollector())

        // Register a service with the `container` scope.
        // The same instance should be shared, even if the collection is resolved many times.
        container
            .registerIntoCollection(CustomService.self) { _ in CustomService(name: "service") }
            .inObjectScope(.container)

        let collection1 = container.resolveCollection(CustomService.self)
        let collection2 = container.resolveCollection(CustomService.self)

        let instance1 = try XCTUnwrap(collection1.entries.first)
        let instance2 = try XCTUnwrap(collection2.entries.first)

        XCTAssert(instance1 === instance2)
    }

    @MainActor
    func test_registerIntoCollection_supportsWeakScopedObjects() throws {
        let swinjectContainer = SwinjectContainer()
        let container = ContainerManager(swinjectContainer: swinjectContainer).register(Any.self)
        container._unwrappedSwinjectContainer().addBehavior(ServiceCollector())

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
        var instance1: CustomService? = try XCTUnwrap(container.resolveCollection(CustomService.self).entries.first)
        XCTAssertEqual(factoryCallCount, 1)

        // Resolving again shouldn't increase `factoryCallCount` since `instance1` is still retained.
        var instance2: CustomService? = try XCTUnwrap(container.resolveCollection(CustomService.self).entries.first)
        XCTAssertEqual(factoryCallCount, 1)
        XCTAssert(instance2 === instance1)

        // Release our instances and resolve again. This time a new instance should be created.
        instance1 = nil
        instance2 = nil
        _ = container.resolveCollection(CustomService.self)
        XCTAssertEqual(factoryCallCount, 2)
    }

    @MainActor
    func test_parentChildContainersWithAssemblers() throws {
        let parent = try ScopedModuleAssembler<ParentResolver>(
            _modules: [AssemblyA()]
        )
        let child = try ScopedModuleAssembler<ChildResolver>(
            parent: parent.internalAssembler,
            _modules: [AssemblyB()]
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
        let parent = try ScopedModuleAssembler<ParentResolver>(
            _modules: [AssemblyC()]
        )
        let child = try ScopedModuleAssembler<ChildResolver>(
            parent: parent.internalAssembler,
            _modules: [AssemblyB()]
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
        let parent = try ScopedModuleAssembler<ParentResolver>(_modules: [AssemblyA()])
        let child = try ScopedModuleAssembler<ChildResolver>(parent: parent.internalAssembler, _modules: [AssemblyD()])

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
        let parent = try ScopedModuleAssembler<ParentResolver>(
            _modules: [AssemblyA()]
        )
        let child = try ScopedModuleAssembler<ChildResolver>(
            parent: parent.internalAssembler,
            _modules: [AssemblyD()]
        )
        let grandChild = try ScopedModuleAssembler<GrandChildResolver>(
            parent: child.internalAssembler,
            _modules: [AssemblyE()]
        )

        // The grand child has access to all services
        XCTAssertEqual(
            grandChild.resolver.resolveCollection(ServiceProtocol.self).allEntries.count,
            2
        )

        // The child has access to parent services
        XCTAssertEqual(
            child.resolver.resolveCollection(ServiceProtocol.self).allEntries.count,
            1
        )

        // The parent has access to its own services
        XCTAssertEqual(
            parent.resolver.resolveCollection(ServiceProtocol.self).allEntries.count,
            1
        )

        // 1 service is registered directly into the grand child
        XCTAssertEqual(
            grandChild.resolver.resolveCollection(ServiceProtocol.self).entries.count,
            1
        )
    }
}
