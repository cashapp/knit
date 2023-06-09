import Knit
import XCTest

protocol ServiceProtocol {}

struct ServiceA: ServiceProtocol {}
struct ServiceB: ServiceProtocol {}

struct CustomService: ServiceProtocol {
    var name: String
}

struct HighArityService: ServiceProtocol, Equatable {
    var string: String
    var uint: UInt
    var int: Int
}

// MARK: -

final class ServiceCollectorTests: XCTestCase {

    func test_registerIntoCollection() {
        let container = Container()
        container.addBehavior(ServiceCollector(for: ServiceProtocol.self))

        // Register some services into a collection
        container.registerIntoCollection(ServiceProtocol.self) { _ in ServiceA() }
        container.registerIntoCollection(ServiceProtocol.self) { _ in ServiceB() }

        // Resolving the collection should produce the services
        let collection = container.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 2)
        XCTAssert(collection.entries.first is ServiceA)
        XCTAssert(collection.entries.last is ServiceB)
    }

    func test_registerIntoCollection_emptyWithBehavior() {
        let container = Container()
        container.addBehavior(ServiceCollector(for: ServiceProtocol.self))

        let collection = container.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 0)
    }

    func test_registerIntoCollection_emptyWithoutBehavior() {
        let container = Container()

        let collection = container.resolveCollection(ServiceProtocol.self)
        XCTAssertEqual(collection.entries.count, 0)
    }

    /// ``ServiceCollector`` uses an ``Array<Service>`` internally, but this
    /// shouldn't preclude users from registering their own, separate ``Array<Service>``.
    /// A conflict here would be confusing and surprising to the user.
    func test_registerIntoCollection_doesntConflictWithArray() throws {
        let container = Container()
        container.addBehavior(ServiceCollector(for: ServiceProtocol.self))

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
        container.addBehavior(ServiceCollector(for: ServiceProtocol.self))

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
        container.addBehavior(ServiceCollector(for: ServiceProtocol.self))

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

    func test_autoregisterIntoCollection() {
        let container = Container()
        container.addBehavior(ServiceCollector(for: ServiceProtocol.self))

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
        container.addBehavior(ServiceCollector(for: ServiceProtocol.self))

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

}
