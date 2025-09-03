//
//  Copyright © 2019 Swinject Contributors. All rights reserved.
//

import Foundation

/// The ``SwinjectContainer`` class represents a dependency injection container, which stores registrations of services
/// and retrieves registered services with dependencies injected.
///
/// **Example to register:**
///
///     let container = Container()
///     container.register(A.self) { _ in B() }
///     container.register(X.self) { r in Y(a: r.resolve(A.self)!) }
///
/// **Example to retrieve:**
///
///     let x = container.resolve(X.self)!
///
/// where `A` and `X` are protocols, `B` is a type conforming `A`, and `Y` is a type conforming `X`
/// and depending on `A`.
public final class SwinjectContainer {
    internal var services = [ServiceKey: ServiceEntryProtocol]()
    private let parent: SwinjectContainer? // Used by HierarchyObjectScope
    private var resolutionDepth = 0
    private let debugHelper: DebugHelper
    private let defaultObjectScope: ObjectScope
    internal var currentObjectGraph: GraphIdentifier?
    internal var graphInstancesInFlight = [ServiceEntryProtocol]()
    internal let lock: RecursiveLock // Used by SynchronizedResolver.
    internal var behaviors = [Behavior]()

    internal init(
        parent: SwinjectContainer? = nil,
        debugHelper: DebugHelper,
        defaultObjectScope: ObjectScope = .graph
    ) {
        self.parent = parent
        self.debugHelper = debugHelper
        lock = parent.map(\.lock) ?? RecursiveLock()
        self.defaultObjectScope = defaultObjectScope
    }

    /// Instantiates a ``SwinjectContainer``
    ///
    /// - Parameters
    ///     - parent: The optional parent ``SwinjectContainer``.
    ///     - defaultObjectScope: Default object scope (graph if no scope is injected)
    ///     - behaviors: List of behaviors to be added to the container
    ///     - registeringClosure: The closure registering services to the new container instance.
    ///
    /// - Remark: Compile time may be long if you pass a long closure to this initializer.
    ///           Use `init()` or `init(parent:)` instead.
    public convenience init(
        parent: SwinjectContainer? = nil,
        defaultObjectScope: ObjectScope = .graph,
        behaviors: [Behavior] = [],
        registeringClosure: (SwinjectContainer) -> Void = { _ in }
    ) {
        self.init(
            parent: parent,
            debugHelper: LoggingDebugHelper(),
            defaultObjectScope: defaultObjectScope
        )
        behaviors.forEach(addBehavior)
        registeringClosure(self)
    }

    /// Removes all registrations in the container.
    public func removeAll() {
        sync { services.removeAll() }
    }

    /// Discards instances for services registered in the given `ObjectsScopeProtocol`.
    ///
    /// **Example usage:**
    ///     container.resetObjectScope(ObjectScope.container)
    ///
    /// - Parameters:
    ///     - objectScope: All instances registered in given `ObjectsScopeProtocol` will be discarded.
    public func resetObjectScope(_ objectScope: ObjectScopeProtocol) {
        sync {
            services.values
                .filter { $0.objectScope === objectScope }
                .forEach { $0.storage.instance = nil }
            parent?.resetObjectScope(objectScope)
        }
    }

    /// Discards instances for services registered in the given `ObjectsScope`. It performs the same operation
    /// as `resetObjectScope(_:ObjectScopeProtocol)`, but provides more convenient usage syntax.
    ///
    /// **Example usage:**
    ///     container.resetObjectScope(.container)
    ///
    /// - Parameters:
    ///     - objectScope: All instances registered in given `ObjectsScope` will be discarded.
    public func resetObjectScope(_ objectScope: ObjectScope) {
        resetObjectScope(objectScope as ObjectScopeProtocol)
    }

    /// Adds a registration for the specified service with the factory closure to specify how the service is
    /// resolved with dependencies.
    ///
    /// - Parameters:
    ///   - serviceType: The service type to register.
    ///   - name:        A registration name, which is used to differentiate from other registrations
    ///                  that have the same service and factory types.
    ///   - factory:     The closure to specify how the service type is resolved with the dependencies of the type.
    ///                  It is invoked when the ``SwinjectContainer`` needs to instantiate the instance.
    ///                  It takes a ``Resolver`` to inject dependencies to the instance,
    ///                  and returns the instance of the component type for the service.
    ///
    /// - Returns: A registered ``ServiceEntry`` to configure more settings with method chaining.
    @discardableResult
    public func register<Service>(
        _ serviceType: Service.Type,
        name: String? = nil,
        factory: @escaping (SwinjectResolver) -> Service
    ) -> ServiceEntry<Service> {
        return _register(serviceType, factory: factory, name: name)
    }

    /// This method is designed for the use to extend Swinject functionality.
    /// Do NOT use this method unless you intend to write an extension or plugin to Swinject framework.
    ///
    /// - Parameters:
    ///   - serviceType: The service type to register.
    ///   - factory:     The closure to specify how the service type is resolved with the dependencies of the type.
    ///                  It is invoked when the ``Container`` needs to instantiate the instance.
    ///                  It takes a ``Resolver`` to inject dependencies to the instance,
    ///                  and returns the instance of the component type for the service.
    ///   - name:        A registration name.
    ///   - option:      A service key option for an extension/plugin.
    ///
    /// - Returns: A registered ``ServiceEntry`` to configure more settings with method chaining.
    @discardableResult
    // swiftlint:disable:next identifier_name
    public func _register<Service, Arguments>(
        _ serviceType: Service.Type,
        factory: @escaping (Arguments) -> Any,
        name: String? = nil,
        option: ServiceKeyOption? = nil
    ) -> ServiceEntry<Service> {
        sync {
            let key = ServiceKey(serviceType: Service.self, argumentsType: Arguments.self, name: name, option: option)
            let entry = ServiceEntry(
                serviceType: serviceType,
                argumentsType: Arguments.self,
                factory: factory,
                objectScope: defaultObjectScope
            )
            entry.container = self
            services[key] = entry

            behaviors.forEach { $0.container(self, didRegisterType: serviceType, toService: entry, withName: name) }

            return entry
        }
    }

    /// Adds behavior to the container. `Behavior.container(_:didRegisterService:withName:)` will be invoked for
    /// each service registered to the `container` **after** the behavior has been added.
    ///
    /// - Parameters:
    ///     - behavior: Behavior to be added to the container
    public func addBehavior(_ behavior: Behavior) {
        sync {
            behaviors.append(behavior)
        }
    }

    /// Check if a `Service` of a given type and name has already been registered.
    ///
    /// - Parameters:
    ///   - serviceType: The service type to compare.
    ///   - name:        A registration name, which is used to differentiate from other registrations
    ///                  that have the same service and factory types.
    ///
    /// - Returns: A  `Bool`  which represents whether or not the `Service` has been registered.
    public func hasAnyRegistration<Service>(
        of serviceType: Service.Type,
        name: String? = nil
    ) -> Bool {
        sync {
            services.contains { key, _ in
                key.serviceType == serviceType && key.name == name
            } || parent?.hasAnyRegistration(of: serviceType, name: name) == true
        }
    }
    
    /// Applies a given GraphIdentifier across resolves in the provided closure.
    /// - Parameters:
    ///   - identifier: Graph scope to use
    ///   - closure: Actions to execute within the Container
    /// - Returns: Any value you return (Void otherwise) within the function call.
    public func withObjectGraph<T>(_ identifier: GraphIdentifier, closure: (SwinjectContainer) throws -> T) rethrows -> T {
        try sync {
            let graphIdentifier = currentObjectGraph
            defer { 
                self.currentObjectGraph = graphIdentifier
                decrementResolutionDepth()
            }
            self.currentObjectGraph = identifier
            incrementResolutionDepth()
            return try closure(self)
        }
    }

    /// Restores the object graph to match the given identifier.
    /// Not synchronized, use lock to edit safely.
    internal func restoreObjectGraph(_ identifier: GraphIdentifier) {
        currentObjectGraph = identifier
    }
}

// MARK: - _Resolver

extension SwinjectContainer: _Resolver {

    /// See documentation on `_Resolver` protocol where this method is declared.
    // swiftlint:disable:next identifier_name
    public func _resolve<Service, Arguments>(
        name: String?,
        option: ServiceKeyOption? = nil,
        invoker: @escaping (SwinjectResolver, (Arguments) -> Any) -> Any
    ) -> Service? {
        // No need to use weak self since the resolution will be executed before
        // this function exits.
        sync {
            var resolvedInstance: Service?
            let key = ServiceKey(serviceType: Service.self, argumentsType: Arguments.self, name: name, option: option)

            if key == Self.graphIdentifierKey {
                return currentObjectGraph as? Service
            }

            if let (entry, resolver) = getEntry(for: key) {
                resolvedInstance = resolve(entry: entry, invoker: invoker, resolver: resolver)
            }

            if resolvedInstance == nil {
                resolvedInstance = resolveAsWrapper(name: name, option: option, invoker: invoker)
            }

            if resolvedInstance == nil {
                debugHelper.resolutionFailed(
                    serviceType: Service.self,
                    key: key,
                    availableRegistrations: getRegistrations()
                )
            }

            return resolvedInstance
        }
    }

    fileprivate func resolveAsWrapper<Wrapper, Arguments>(
        name: String?,
        option: ServiceKeyOption?,
        invoker: @escaping (SwinjectResolver, (Arguments) -> Any) -> Any
    ) -> Wrapper? {
        guard let wrapper = Wrapper.self as? InstanceWrapper.Type else { return nil }

        let key = ServiceKey(
            serviceType: wrapper.wrappedType, argumentsType: Arguments.self, name: name, option: option
        )

        if let (entry, resolver) = getEntry(for: key) {
            let factory = { [weak self] (graphIdentifier: GraphIdentifier?) -> Any? in
                self?.sync { [weak self] () -> Any? in
                    guard let self else { return nil }
                    let originGraph = self.currentObjectGraph
                    defer { originGraph.map { self.restoreObjectGraph($0) } }
                    if let graphIdentifier = graphIdentifier {
                        self.restoreObjectGraph(graphIdentifier)
                    }
                    return self.resolve(entry: entry, invoker: invoker, resolver: resolver) as Any?
                }
            }
            return wrapper.init(inContainer: self, withInstanceFactory: factory) as? Wrapper
        } else {
            return wrapper.init(inContainer: self, withInstanceFactory: nil) as? Wrapper
        }
    }

    fileprivate func getRegistrations() -> [ServiceKey: ServiceEntryProtocol] {
        var registrations = parent?.getRegistrations() ?? [:]
        services.forEach { key, value in registrations[key] = value }
        return registrations
    }

    fileprivate var maxResolutionDepth: Int { return 200 }

    fileprivate func incrementResolutionDepth() {
        parent?.incrementResolutionDepth()
        if resolutionDepth == 0, currentObjectGraph == nil {
            currentObjectGraph = GraphIdentifier()
        }
        guard resolutionDepth < maxResolutionDepth else {
            fatalError("Infinite recursive call for circular dependency has been detected. " +
                "To avoid the infinite call, 'initCompleted' handler should be used to inject circular dependency.")
        }
        resolutionDepth += 1
    }

    fileprivate func decrementResolutionDepth() {
        parent?.decrementResolutionDepth()
        assert(resolutionDepth > 0, "The depth cannot be negative.")

        resolutionDepth -= 1
        if resolutionDepth == 0 { graphResolutionCompleted() }
    }

    fileprivate func graphResolutionCompleted() {
        graphInstancesInFlight.forEach { $0.storage.graphResolutionCompleted() }
        graphInstancesInFlight.removeAll(keepingCapacity: true)
        currentObjectGraph = nil
    }
}

// MARK: - Resolver

extension SwinjectContainer: SwinjectResolver {
    /// Retrieves the instance with the specified service type.
    ///
    /// - Parameter serviceType: The service type to resolve.
    ///
    /// - Returns: The resolved service type instance, or nil if no registration for the service type
    ///            is found in the ``SwinjectContainer``.
    public func resolve<Service>(_ serviceType: Service.Type) -> Service? {
        return resolve(serviceType, name: nil)
    }

    /// Retrieves the instance with the specified service type and registration name.
    ///
    /// - Parameters:
    ///   - serviceType: The service type to resolve.
    ///   - name:        The registration name.
    ///
    /// - Returns: The resolved service type instance, or nil if no registration for the service type and name
    ///            is found in the ``SwinjectContainer``.
    public func resolve<Service>(_: Service.Type, name: String?) -> Service? {
        return _resolve(
            name: name,
            invoker: { (resolver: SwinjectResolver, factory: (SwinjectResolver) -> Any) in
                factory(resolver)
            }
        )
    }

    /// Retrieve the service entry for a given service key.
    ///
    /// - Returns: An optional tuple of the service entry and the source resolver.
    fileprivate func getEntry(for key: ServiceKey) -> (ServiceEntryProtocol, SwinjectResolver)? {
        if let entry = services[key] {
            return (entry, self)
        } else if let parentResult = parent?.getEntry(for: key) {
            // An entry from a parent container uses that same parent container as the source resolver
            return parentResult
        } else {
            return nil
        }
    }

    fileprivate func resolve<Service, Factory>(
        entry: ServiceEntryProtocol,
        invoker: @escaping (SwinjectResolver, Factory) -> Any,
        resolver: SwinjectResolver
    ) -> Service? {
        self.incrementResolutionDepth()
        defer { self.decrementResolutionDepth() }

        guard let currentObjectGraph = self.currentObjectGraph else {
            fatalError("If accessing container from multiple threads, make sure to use a synchronized resolver.")
        }

        if let persistedInstance = self.persistedInstance(Service.self, from: entry, in: currentObjectGraph) {
            return persistedInstance
        }

        let resolvedInstance = invoker(resolver, entry.factory as! Factory)
        if let persistedInstance = self.persistedInstance(Service.self, from: entry, in: currentObjectGraph) {
            // An instance for the key might be added by the factory invocation.
            return persistedInstance
        }
        entry.storage.setInstance(resolvedInstance as Any, inGraph: currentObjectGraph)
        graphInstancesInFlight.append(entry)

        if let completed = entry.initCompleted as? (SwinjectResolver, Any) -> Void,
           let resolvedInstance = resolvedInstance as? Service {
            completed(self, resolvedInstance)
        }

        return resolvedInstance as? Service
    }

    private func persistedInstance<Service>(
        _: Service.Type, from entry: ServiceEntryProtocol, in graph: GraphIdentifier
    ) -> Service? {
        if let instance = entry.storage.instance(inGraph: graph), let service = instance as? Service {
            return service
        } else {
            return nil
        }
    }

    @inline(__always)
    @discardableResult
    internal func sync<T>(_ action: () throws -> T) rethrows -> T {
        try lock.sync(action)
    }
}

// MARK: CustomStringConvertible

extension SwinjectContainer: CustomStringConvertible {
    public var description: String {
        return "["
            + services.map { "\n    { \($1.describeWithKey($0)) }" }.sorted().joined(separator: ",")
            + "\n]"
    }
}

// MARK: Constants

private extension SwinjectContainer {
    static let graphIdentifierKey = ServiceKey(serviceType: GraphIdentifier.self, argumentsType: SwinjectResolver.self)
}
