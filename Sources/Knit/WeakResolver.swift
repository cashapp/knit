//
// Copyright © Block, Inc. All rights reserved.
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

    public func resolve<Service, each Argument>(
        _ serviceType: Service.Type,
        name: String?,
        arguments: repeat each Argument
    ) -> Service? {
        return unwrapped.resolve(serviceType, name: name, arguments: repeat each arguments)
    }

    public func resolve<Service>(_ serviceType: Service.Type, name: String?) -> Service? {
        return unwrapped.resolve(serviceType, name: name)
    }
}
