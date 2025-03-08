//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import Swinject

/// A Swinject behavior that aggregates all services registered using
/// ``Container/registerIntoCollection(_:factory:)`` or
///
/// Usage:
/// ```
/// let container = Container()
/// container.addBehavior(ServiceCollector())
/// container.registerIntoCollection(Animal.self) { _ in Cat() })
/// container.registerIntoCollection(Animal.self) { _ in Dog() })
///
/// let animals = resolver.resolveCollection(Animal.self)
/// print(animals.entries) // [Cat, Dog]
/// ```
/// - Important: All services must be registered using the same Service type. This is typically a protocol
///              that several concrete implementations conform to.
public final class ServiceCollector: Behavior {

    /// Maps a service type to an array of service factories
    /// Note: We use `ObjectIdentifier` to represent the service type since `Any.Type` isn't Hashable.
    private var factoriesByService: [ObjectIdentifier: [(Resolver) -> Any]] = [:]

    private let parent: ServiceCollector?

    public init(parent: ServiceCollector? = nil) {
        self.parent = parent
    }

    public func container<Type, Service>(
        _ container: Container,
        didRegisterType type: Type.Type,
        toService entry: ServiceEntry<Service>,
        withName name: String?
    ) {
        guard name?.hasPrefix(collectionRegistrationPrefix) == true else {
            // This service wasn't explicitly registered into a collection. Ignore it.
            return
        }

        if factoriesByService[ObjectIdentifier(Service.self)] == nil {
            // This is the first factory for this service to be registered into a collection.
            // Register a `ServiceCollection` for it:
            container.register(ServiceCollection<Service>.self) { resolver in
                return self.resolveServices(resolver: resolver)
            }.inObjectScope(.transient)
        }
        var factories = factoriesByService[ObjectIdentifier(Service.self)] ?? []
        factories.append {
            guard let service = $0.resolve(Service.self, name: name) else {
                fatalError("Could not resolve \(Service.self) inside ServiceCollector")
            }
            return service
        }
        factoriesByService[ObjectIdentifier(Service.self)] = factories
    }
    
    private func resolveServices<Service>(resolver: Resolver) -> ServiceCollection<Service> {
        let parentCollection: ServiceCollection<Service>? = parent?.resolveServices(resolver: resolver)
        let factories = self.factoriesByService[ObjectIdentifier(Service.self)] ?? []
        let entries = factories.map { $0(resolver) as! Service }
        return .init(parent: parentCollection, entries: entries)
    }
}

// MARK: -

/**
 A prefix for named registrations that should be collected using a ``ServiceCollector``.
 See also:
 - ``ServiceCollector/container(_:didRegisterType:toService:withName:)``
 - ``Container/registerIntoCollection(_:factory:)``
 */
internal let collectionRegistrationPrefix = "ServiceCollection"
