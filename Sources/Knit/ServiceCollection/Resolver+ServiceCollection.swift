//
// Copyright © Block, Inc. All rights reserved.
//

import Swinject

extension Swinject.Resolver {

    /// Resolves a collection of all services registered using
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
    /// - Parameter serviceType: The service types to resolve.
    /// - Returns: A ``ServiceCollection`` containing all registered services,
    ///            or an empty collection if no services were registered.
    @MainActor
    public func resolveCollection<Service>(_ serviceType: Service.Type) -> ServiceCollection<Service> {
        resolve(ServiceCollection<Service>.self) ?? .init(parent: nil, entries: [])
    }

}
