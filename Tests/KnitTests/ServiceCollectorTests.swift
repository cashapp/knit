//
// Copyright © Block, Inc. All rights reserved.
//

import Knit
import XCTest

protocol ServiceProtocol {}

struct ServiceA: ServiceProtocol {}

struct ServiceB: ServiceProtocol {}

struct AssemblyA: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] = []

    func assemble(container: Container) {
        container.registerIntoCollection(ServiceProtocol.self, factory: { _ in ServiceA() })
    }
}

struct AssemblyB: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] = []

    func assemble(container: Container) {
        container.registerIntoCollection(ServiceProtocol.self, factory: { _ in ServiceB() })
    }
}

struct AssemblyC: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] = []

    func assemble(container: Container) { }
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

    func test_registerIntoCollection() {
        let container = Container()
        container.addBehavior(ServiceCollector())

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

    func test_registerIntoCollection_emptyWithBehavior() {
        let container = Container()
        container.addBehavior(ServiceCollector())

        let collection = container.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 0)
    }

    func test_registerIntoCollection_emptyWithoutBehavior() {
        let container = Container()

        let collection = container.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 0)
    }

    /// ``ServiceCollector`` shouldn't preclude users from registering their own separate ``Array<Service>``.
    /// A conflict here would be confusing and surprising to the user.
    func test_registerIntoCollection_doesntConflictWithArray() throws {
        let container = Container()
        container.addBehavior(ServiceCollector())

        // Register A into a collection
        container.registerIntoCollection(ServiceProtocol.self) { _ in ServiceA() }

        // Register B as an array
        container.register([ServiceProtocol].self) { _ in [ServiceB()] }

        // Resolving the collection should produce A
        let collection = container.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 1)
        XCTAssert(collection.entries.first is ServiceA)

        // Resolving the array should produce B
        let array = try XCTUnwrap(container.resolve([ServiceProtocol].self))
        XCTAssertEqual(array.count, 1)
        XCTAssert(array.first is ServiceB)
    }

    func test_registerIntoCollection_doesntImplicitlyAggregateInstances() throws {
        let container = Container()
        container.addBehavior(ServiceCollector())

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
        XCTAssert(container.resolve(ServiceProtocol.self) is ServiceB)
    }

    func test_registerIntoCollection_allowsDuplicates() {
        let container = Container()
        container.addBehavior(ServiceCollector())

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

    // MARK: - Tests - autoregisterIntoCollection

    func test_autoregisterIntoCollection() {
        let container = Container()
        container.addBehavior(ServiceCollector())

        // Register some services into a collection
        container.autoregisterIntoCollection(ServiceProtocol.self, initializer: ServiceA.init)
        container.autoregisterIntoCollection(ServiceProtocol.self, initializer: ServiceB.init)

        // Resolving the collection should produce the services
        let collection = container.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 2)
        XCTAssert(collection.entries.first is ServiceA)
        XCTAssert(collection.entries.last is ServiceB)
    }

    // High-arity overloads are generated by a script. Ensure they work as expected.
    func test_autoregisterIntoCollection_highArityOverloads() {
        let container = Container()
        container.addBehavior(ServiceCollector())

        // Register dependencies for autoregistration
        container.register(String.self) { _ in "string" }
        container.register(UInt.self) { _ in 1 }
        container.register(Int.self) { _ in 2 }

        // Register a high-arity service into a collection
        container.autoregisterIntoCollection(ServiceProtocol.self, initializer: HighArityService.init)

        // Resolving the collection should produce the service
        let collection = container.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 1)
        XCTAssertEqual(
            collection.entries.first as? HighArityService,
            HighArityService(string: "string", uint: 1, int: 2)
        )
    }

    // MARK: - Tests - Object Scopes

    func test_registerIntoCollection_supportsTransientScopedObjects() throws {
        let container = Container()
        container.addBehavior(ServiceCollector())

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

    func test_registerIntoCollection_supportsContainerScopedObjects() throws {
        let container = Container()
        container.addBehavior(ServiceCollector())

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

    func test_registerIntoCollection_supportsWeakScopedObjects() throws {
        let container = Container()
        container.addBehavior(ServiceCollector())

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

    func test_parentChildContainersWithAssemblers() {
        let parent = ModuleAssembler([AssemblyA()])
        let child = ModuleAssembler(parent: parent, [AssemblyB()])
        
        // When resolving from the parent resolver we only get services from AssemblyA
        XCTAssertEqual(
            parent.resolver.resolveCollection(ServiceProtocol.self).entries.count,
            1
        )

        // When resolving from the child resolver we get both
        XCTAssertEqual(
            child.resolver.resolveCollection(ServiceProtocol.self).entries.count,
            2
        )
    }

    func test_childWithEmptyParent() {
        let parent = ModuleAssembler([AssemblyC()])
        let child = ModuleAssembler(parent: parent, [AssemblyB()])

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

}
