//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import Swinject

/**
 A light-weight wrapper around the `Swinject.Container` that adds type information about the `TargetResolver`.
 This allows us to provide registration APIs that are specified to the `TargetResolver`.

 The Knit.Container also performs the function of a weak wrapper of the `Swinject.Container`.
 */
public class Container<TargetResolver>: Knit.Resolver {

    // MARK: - Knit.Resolver

    public var resolver: TargetResolver {
        self as! TargetResolver
    }

    /// Returns `true` if the backing container is still available in memory, otherwise `false`.
    public var isAvailable: Bool {
        _swinjectContainer != nil
    }

    // MARK: - Swinject.Resolver

    public var unsafeResolver: Swinject.Resolver {
        _unwrappedSwinjectContainer
    }

    // MARK: - Private Properties

    private weak var _swinjectContainer: Swinject.Container?

    // MARK: - Life Cycle

    // This should not be promoted from `fileprivate` access level.
    fileprivate init(_swinjectContainer: Swinject.Container) {
        self._swinjectContainer = _swinjectContainer
    }

    // **NOTE**: The only place this should be called is from the ModuleAssembler which
    // is responsible for creating Containers.
    // This should not be promoted from `internal` access level.
    @discardableResult
    internal static func _instantiateAndRegister(_swinjectContainer: Swinject.Container) -> Container {
        let container = Container(_swinjectContainer: _swinjectContainer)

        // We don't want to make multiple copies of this Knit.Container wrapper,
        // so store an instance of it in the wrapped container.
        // This class only holds a weak reference to the wrapped container so no retain cycle is created.
        _swinjectContainer.register(
            Container<TargetResolver>.self,
            factory: { _ in container }
        )

        return container
    }

}

extension Container {

    // Force unwraps the weak Container
    var _unwrappedSwinjectContainer: Swinject.Container {
        guard let _swinjectContainer else {
            fatalError("Attempting to resolve using the container for \(TargetResolver.self) which has been released")
        }
        return _swinjectContainer
    }

}
