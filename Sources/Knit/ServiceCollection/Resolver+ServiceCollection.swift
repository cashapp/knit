//
// Copyright © Block, Inc. All rights reserved.
//

extension Resolver {

    /// Resolves a collection of all services registered using
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
    /// - Parameter serviceType: The service types to resolve.
    /// - Returns: A ``ServiceCollection`` containing all registered services,
    ///            or an empty collection if no services were registered.
    public func resolveCollection<Service>(_ serviceType: Service.Type) -> ServiceCollection<Service> {
        resolve(ServiceCollection<Service>.self) ?? .init(parent: nil, entries: [])
    }

}
