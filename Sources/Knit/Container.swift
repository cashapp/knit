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

    public func unsafeResolver(file: StaticString, function: StaticString, line: UInt) -> Swinject.Resolver {
        _unwrappedSwinjectContainer(file: file, function: function, line: line)
    }

    // MARK: - Private Properties

    private weak var _swinjectContainer: Swinject.Container?

    // MARK: - Life Cycle

    // This should not be promoted from `fileprivate` access level.
    fileprivate init(_swinjectContainer: Swinject.Container) {
        self._swinjectContainer = _swinjectContainer
    }
}

extension Container {

    // Force unwraps the weak Container
    func _unwrappedSwinjectContainer(
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) -> Swinject.Container {
        guard let _swinjectContainer else {
            fatalError(
                """
                \(function) incorrectly accessed the container for \(TargetResolver.self) which has already been released.
                This may be caused by a memory leak of an object defined in \(file) which is holding a reference to a Knit resolver.
                """,
                file: file,
                line: line
            )
        }
        return _swinjectContainer
    }

}

// **NOTE**: The only place this should be created is from the ModuleAssembler which
// is responsible for creating Containers.
// This should not be promoted from `internal` access level.
internal final class ContainerManager {

    // swinjectContainer is weak since the container will own this manager
    private weak var swinjectContainer: Swinject.Container!

    // ContainerManager from the parent of the SwinjectContainer
    private let parent: ContainerManager?

    /// Dictionary of Containers that have been registered
    private var containers: [ObjectIdentifier: Any] = [:]

    /// Whether to automatically create Containers which are not registered
    private let autoConfigureContainers: Bool

    init(
        parent: ContainerManager? = nil,
        swinjectContainer: Swinject.Container,
        autoConfigureContainers: Bool = false
    ) {
        self.parent = parent
        self.autoConfigureContainers = autoConfigureContainers
        self.swinjectContainer = swinjectContainer

        // Set this as the manager for the container
        swinjectContainer.register(ContainerManager.self) { _ in
            self
        }
    }

    func get<TargetResolver>(_ targetResolver: TargetResolver.Type = TargetResolver.self) -> Container<TargetResolver> {
        if let container = getOptional(TargetResolver.self) {
            return container
        }
        if autoConfigureContainers {
            return register()
        }
        fatalError("ModuleAssembler failed to locate appropriate Container for \(String(describing: TargetResolver.self))")
    }

    private func getOptional<TargetResolver>(
        _ targetResolver: TargetResolver.Type = TargetResolver.self
    ) -> Container<TargetResolver>? {
        // Check if this manager already has the Container
        if let container = containers[ObjectIdentifier(TargetResolver.self)] as? Container<TargetResolver> {
            return container
        }

        // See if the parent manager has the Container
        if let parentContainer = parent?.getOptional(TargetResolver.self) {
            return parentContainer
        }
        return nil
    }

    @discardableResult func register<TargetResolver>(
        _ targetResolver: TargetResolver.Type = TargetResolver.self
    ) -> Container<TargetResolver> {
        let container = Container<TargetResolver>(_swinjectContainer: swinjectContainer)
        self.containers[ObjectIdentifier(TargetResolver.self)] = container
        swinjectContainer.register(Container<TargetResolver>.self) { _ in
            container
        }
        return container
    }
}
