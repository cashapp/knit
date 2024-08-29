//
// NOTICE:
//
// This file is generated from Container+ServiceCollection.erb by ERB.
// Do NOT modify it directly.
// Instead, modify Container+ServiceCollection.erb and run `scripts/gencode`.
//

import Foundation

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
        factory: @escaping @MainActor (Resolver) -> Service
    ) -> ServiceEntry<Service> {
        self.register(
            service,
            name: makeUniqueCollectionRegistrationName(),
            factory: { resolver in
                MainActor.assumeIsolated {
                    return factory(resolver)
                }
            }
        )
    }

    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: The service type to register.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service>(
        _ service: Service.Type,
        initializer: @escaping (()) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }

    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1>(
        _ service: Service.Type,
        initializer: @escaping ((T1)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6, T7>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6, T7)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6, T7, T8>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6, T7, T8)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6, T7, T8, T9>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6, T7, T8, T9)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }
    /// Registers a service factory into a collection.
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
    /// - Parameters:
    ///   - service: Registered service type.
    ///   - initializer: Initializer of the registered service.
    /// - Returns: The registered service entry.
    @discardableResult
    public func autoregisterIntoCollection<Service, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20>(
        _ service: Service.Type,
        initializer: @escaping ((T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20)) -> Service
    ) -> ServiceEntry<Service> {
        self.autoregister(service, name: makeUniqueCollectionRegistrationName(), initializer: initializer)
    }

    // MARK: - Private Methods

    private func makeUniqueCollectionRegistrationName() -> String {
        "\(collectionRegistrationPrefix)-\(UUID().uuidString)"
    }

}
