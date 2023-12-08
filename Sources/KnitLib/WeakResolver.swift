//
// Copyright © Square, Inc. All rights reserved.
//

import Swinject

/// A resolver that weakly holds onto the container. This allows keeping a reference without the risk of leaking the container
/// Classes holding onto a WeakResolver do not take ownership of the DI graph
/// This allows the container to be deallocated even if services still have references to it
public final class WeakResolver {

    private weak var container: Container?

    public init(container: Container) {
        self.container = container
    }

    /// Returns `true` if the backing container is still available in memory, otherwise `false`.
    public var isAvailable: Bool { return container != nil }

    /// Only provide a resolver if it is still available in memory, otherwise return `nil`.
    /// Syntax sugar to allow optional chaining on the instance.
    public var optionalResolver: Resolver? {
        // We are returning `self` rather than the container to maintain weak semantics
        isAvailable ? self : nil
    }
}

// MARK: - Resolver conformance

extension WeakResolver: Resolver {

    // Force unwraps the weak Container
    // Convenience accessor for private implementation
    private var unwrapped: Resolver {
        guard let container else {
            fatalError("Attempting to resolve using a container which has been released")
        }
        return container
    }

    public func resolve<Service>(_ serviceType: Service.Type) -> Service? {
        unwrapped.resolve(serviceType)
    }

    public func resolve<Service>(_ serviceType: Service.Type, name: String?) -> Service? {
        unwrapped.resolve(serviceType, name: name)
    }

    public func resolve<Service, Arg1>(_ serviceType: Service.Type, argument: Arg1) -> Service? {
        unwrapped.resolve(serviceType, argument: argument)
    }

    public func resolve<Service, Arg1>(_ serviceType: Service.Type, name: String?, argument: Arg1) -> Service? {
        unwrapped.resolve(serviceType, name: name, argument: argument)
    }

    public func resolve<Service, Arg1, Arg2>(_ serviceType: Service.Type, arguments arg1: Arg1, _ arg2: Arg2) -> Service? {
        unwrapped.resolve(serviceType, arguments: arg1, arg2)
    }

    public func resolve<Service, Arg1, Arg2>(_ serviceType: Service.Type, name: String?, arguments arg1: Arg1, _ arg2: Arg2) -> Service? {
        unwrapped.resolve(serviceType, name: name, arguments: arg1, arg2)
    }

    public func resolve<Service, Arg1, Arg2, Arg3>(_ serviceType: Service.Type, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3) -> Service? {
        unwrapped.resolve(serviceType, arguments: arg1, arg2, arg3)
    }

    public func resolve<Service, Arg1, Arg2, Arg3>(_ serviceType: Service.Type, name: String?, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3) -> Service? {
        unwrapped.resolve(serviceType, name: name, arguments: arg1, arg2, arg3)
    }

    public func resolve<Service, Arg1, Arg2, Arg3, Arg4>(_ serviceType: Service.Type, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4) -> Service? {
        unwrapped.resolve(serviceType, arguments: arg1, arg2, arg3, arg4)
    }

    public func resolve<Service, Arg1, Arg2, Arg3, Arg4>(_ serviceType: Service.Type, name: String?, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4) -> Service? {
        unwrapped.resolve(serviceType, name: name, arguments: arg1, arg2, arg3, arg4)
    }

    public func resolve<Service, Arg1, Arg2, Arg3, Arg4, Arg5>(_ serviceType: Service.Type, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5) -> Service? {
        unwrapped.resolve(serviceType, arguments: arg1, arg2, arg3, arg4, arg5)
    }

    public func resolve<Service, Arg1, Arg2, Arg3, Arg4, Arg5>(_ serviceType: Service.Type, name: String?, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5) -> Service? {
        unwrapped.resolve(serviceType, name: name, arguments: arg1, arg2, arg3, arg4, arg5)
    }

    public func resolve<Service, Arg1, Arg2, Arg3, Arg4, Arg5, Arg6>(_ serviceType: Service.Type, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6) -> Service? {
        unwrapped.resolve(serviceType, arguments: arg1, arg2, arg3, arg4, arg5, arg6)
    }

    public func resolve<Service, Arg1, Arg2, Arg3, Arg4, Arg5, Arg6>(_ serviceType: Service.Type, name: String?, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6) -> Service? {
        unwrapped.resolve(serviceType, name: name, arguments: arg1, arg2, arg3, arg4, arg5, arg6)
    }

    public func resolve<Service, Arg1, Arg2, Arg3, Arg4, Arg5, Arg6, Arg7>(_ serviceType: Service.Type, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6, _ arg7: Arg7) -> Service? {
        unwrapped.resolve(serviceType, arguments: arg1, arg2, arg3, arg4, arg5, arg6, arg7)
    }

    public func resolve<Service, Arg1, Arg2, Arg3, Arg4, Arg5, Arg6, Arg7>(_ serviceType: Service.Type, name: String?, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6, _ arg7: Arg7) -> Service? {
        unwrapped.resolve(serviceType, name: name, arguments: arg1, arg2, arg3, arg4, arg5, arg6, arg7)
    }

    public func resolve<Service, Arg1, Arg2, Arg3, Arg4, Arg5, Arg6, Arg7, Arg8>(_ serviceType: Service.Type, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6, _ arg7: Arg7, _ arg8: Arg8) -> Service? {
        unwrapped.resolve(serviceType, arguments: arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    }

    public func resolve<Service, Arg1, Arg2, Arg3, Arg4, Arg5, Arg6, Arg7, Arg8>(_ serviceType: Service.Type, name: String?, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6, _ arg7: Arg7, _ arg8: Arg8) -> Service? {
        unwrapped.resolve(serviceType, name: name, arguments: arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    }

    public func resolve<Service, Arg1, Arg2, Arg3, Arg4, Arg5, Arg6, Arg7, Arg8, Arg9>(_ serviceType: Service.Type, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6, _ arg7: Arg7, _ arg8: Arg8, _ arg9: Arg9) -> Service? {
        unwrapped.resolve(serviceType, arguments: arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
    }

    public func resolve<Service, Arg1, Arg2, Arg3, Arg4, Arg5, Arg6, Arg7, Arg8, Arg9>(_ serviceType: Service.Type, name: String?, arguments arg1: Arg1, _ arg2: Arg2, _ arg3: Arg3, _ arg4: Arg4, _ arg5: Arg5, _ arg6: Arg6, _ arg7: Arg7, _ arg8: Arg8, _ arg9: Arg9) -> Service? {
        unwrapped.resolve(serviceType, name: name, arguments: arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
    }
}
