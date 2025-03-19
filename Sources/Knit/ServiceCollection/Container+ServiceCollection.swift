import Foundation
import Swinject

extension Container {

    /// Registers a service factory into a collection.
    ///
    /// Usage:
    /// ```
    /// let container = Container()
    /// container.addBehavior(ServiceCollector())
    /// container.registerIntoCollection(Animal.self) { _ in Cat(...) }
    /// container.registerIntoCollection(Animal.self) { _ in Dog(...) }
    ///
    /// let animals = resolver.resolveCollection(Animal.self)
    /// print(animals.entries) // [Cat, Dog]
    /// ```
    /// - Parameters:
    ///   - service: The service type to register.
    ///   - factory: The closure to specify how the service type is resolved with the dependencies of the type.
    ///              It is invoked when the ``Container`` needs to instantiate the instance.
    ///              It takes a ``Resolver`` to inject dependencies to the instance,
    ///              and returns the instance of the component type for the service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func registerIntoCollection<Service>(
        _ service: Service.Type,
        factory: @escaping @MainActor (TargetResolver) -> Service
    ) -> ServiceEntry<Service> {
        self._unwrappedSwinjectContainer.register(
            service,
            name: makeUniqueCollectionRegistrationName(),
            factory: { r in
                MainActor.assumeIsolated {
                    let resolver = r.resolve(Container<TargetResolver>.self)! as! TargetResolver
                    return factory(resolver)
                }
            }
        )
    }

    // MARK: - Private Methods

    private func makeUniqueCollectionRegistrationName() -> String {
        "\(collectionRegistrationPrefix)-\(UUID().uuidString)"
    }

}
