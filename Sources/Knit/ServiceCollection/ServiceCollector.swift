import Foundation
import Swinject

/// A Swinject behavior that aggregates all services registered using
/// ``Container/registerIntoCollection(_:factory:)`` or
/// ``Container/autoregisterIntoCollection(_:initializer:)``
///
/// Usage:
/// ```
/// let container = Container()
/// container.addBehavior(ServiceCollector())
/// container.autoregisterIntoCollection(Animal.self, initializer: Cat.init)
/// container.autoregisterIntoCollection(Animal.self, initializer: Dog.init)
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

    public init() {}

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
                let factories = self.factoriesByService[ObjectIdentifier(type)]!
                return .init(entries: factories.map { $0(resolver) as! Service })
            }
        }
        var factories = factoriesByService[ObjectIdentifier(Service.self)] ?? []
        factories.append {
            $0.resolve(Service.self, name: name)!
        }
        factoriesByService[ObjectIdentifier(Service.self)] = factories
    }
}

// MARK: -

/**
 A prefix for named registrations that should be collected using a ``ServiceCollector``.
 See also:
 - ``ServiceCollector/container(_:didRegisterType:toService:withName:)``
 - ``Container/registerIntoCollection(_:factory:)``
 - ``Container.autoregisterIntoCollection(_:initializer:)``
 */
internal let collectionRegistrationPrefix = "ServiceCollection"
