//
// Copyright © Block, Inc. All rights reserved.
//

import Swinject

extension SwinjectResolver {

    /// Resolves a collection of all services registered using
    /// ``Container/registerIntoCollection(_:factory:)``
    ///
    /// Usage:
    /// ```
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

// MARK: - Knit Resolver

extension Knit.Resolver {

    /// Resolves a collection of all services registered using
    /// ``Container/registerIntoCollection(_:factory:)``
    ///
    /// Usage:
    /// ```
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
    public func resolveCollection<Service>(
        _ serviceType: Service.Type,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) -> ServiceCollection<Service> {
        unsafeResolver(file: file, function: function, line: line)
            .resolveCollection(serviceType)
    }

}
