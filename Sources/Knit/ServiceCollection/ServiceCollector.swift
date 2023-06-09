import Foundation

/// A Swinject behavior that aggregates all services registered using
/// ``Container/registerIntoCollection(_:factory:)`` or
/// ``Container/autoregisterIntoCollection(_:initializer:)``
///
/// Usage:
/// ```
/// let container = Container()
/// container.addBehavior(ServiceCollector(for: Animal.self))
/// container.autoregisterIntoCollection(Animal.self, initializer: Cat.init)
/// container.autoregisterIntoCollection(Animal.self, initializer: Dog.init)
///
/// let animals = resolver.resolveCollection(Animal.self)
/// print(animals.entries) // [Cat, Dog]
/// ```
/// - Important: All services must be registered using the same Service type. This is typically a protocol
///              that several concrete implementations conform to.
public final class ServiceCollector<T>: Behavior {
    private var factories: [(Resolver) -> T?] = []

    public init(for aggregatedType: T.Type) {}

    public func container<Type, Service>(
        _ container: Container,
        didRegisterType type: Type.Type,
        toService entry: ServiceEntry<Service>,
        withName name: String?
    ) {
        guard Service.self == T.self else {
            // We're not collecting this service type. Ignore it.
            return
        }

        guard name?.hasPrefix(collectionRegistrationPrefix) == true else {
            // This service wasn't explicitly registered into a collection. Ignore it.
            return
        }

        if factories.isEmpty {
            container.register(ServiceCollection<T>.self) { resolver in
                .init(entries: self.factories.compactMap { $0(resolver) })
            }
        }
        factories.append {
            $0.resolve(Service.self, name: name) as? T
        }
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
