//
// Copyright © Block, Inc. All rights reserved.
//

import Swinject

/// ModuleAssembler wraps the Swinject Assembler to resolve the full tree of module dependencies.
/// If dependencies are missing from the tree then the resolution will fail and indicate the missing module
public final class ModuleAssembler {

    /// The container that registrations have been placed in. Prefer using resolver unless mutable access is required
    let _swinjectContainer: Swinject.Container
    let containerManager: ContainerManager
    let parent: ModuleAssembler?
    let serviceCollector: ServiceCollector
    private let autoConfigureContainers: Bool

    /// The unsafe resolver for this ModuleAssembler's container
    public var resolver: Swinject.Resolver { _swinjectContainer }

    // Module types that were registered into the container owned by this ModuleAssembler
    var registeredReferences: [AssemblyReference] {
        builder.assemblyCache.assemblyList
    }

    let builder: DependencyBuilder

    /**
     The created ModuleAssembler will manage finding and applying registrations from all module assemblies.
     A depth first search will find all dependencies which will be registered.

     - NOTE: Direct use of ModuleAssembler in your app will not provide safety for separation of TargetResolvers.
        Specified generic Containers will be *automatically* created for any TargetResolver that is later used.
        Using ModuleAssembler in this way also disallows parent-child container configuration.
        If your app has multiple TargetResolvers you should only use the ScopedModuleAssembler instead.

     - Parameters:
        - modules: Array of modules to register
        - overrideBehavior: Behavior of default override usage.
        - assemblyValidation: An optional closure to perform custom validation on module assemblies for this assembler.
            The Assembler will invoke this closure with each ModuleAssembly.Type as it performs its initialization.
            If the closure throws an error for any of the assemblies then a fatal error will occur.
        - postAssemble: Hook after all assemblies are registered to make changes to the container.
     */
    @MainActor public convenience init(
        _ modules: [any ModuleAssembly],
        overrideBehavior: OverrideBehavior = .defaultOverridesWhenTesting,
        assemblyValidation: ((any ModuleAssembly.Type) throws -> Void)? = nil,
        errorFormatter: ModuleAssemblerErrorFormatter = DefaultModuleAssemblerErrorFormatter(),
        postAssemble: ((Swinject.Container) -> Void)? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        // Hold an optional reference to be used by error handling later
        var createdBuilder: DependencyBuilder?
        do {
            try self.init(
                parent: nil,
                _modules: modules,
                overrideBehavior: overrideBehavior,
                assemblyValidation: assemblyValidation,
                errorFormatter: errorFormatter, 
                preAssemble: nil,
                postAssemble: postAssemble,
                autoConfigureContainers: true
            )
            createdBuilder = self.builder
        } catch {
            let message = errorFormatter.format(error: error, dependencyTree: createdBuilder?.dependencyTree)
            fatalError(
                message,
                file: file,
                line: line
            )
        }
    }

    // Internal required init that throws rather than fatal errors
    @MainActor required init(
        parent: ModuleAssembler? = nil,
        _modules modules: [any ModuleAssembly],
        overrideBehavior: OverrideBehavior = .defaultOverridesWhenTesting,
        assemblyValidation: ((any ModuleAssembly.Type) throws -> Void)? = nil,
        errorFormatter: ModuleAssemblerErrorFormatter = DefaultModuleAssemblerErrorFormatter(),
        behaviors: [Behavior] = [],
        preAssemble: ((Swinject.Container) -> Void)?,
        postAssemble: ((Swinject.Container) -> Void)? = nil,
        autoConfigureContainers: Bool
    ) throws {
        self.builder = try DependencyBuilder(
            modules: modules,
            assemblyValidation: assemblyValidation,
            overrideBehavior: overrideBehavior,
            isRegisteredInParent: { type in
                return parent?.isRegistered(type) ?? false
            }
        )

        self.parent = parent
        let _swinjectContainer = Swinject.Container(
            parent: parent?._swinjectContainer,
            behaviors: behaviors
        )
        self._swinjectContainer = _swinjectContainer
        self.containerManager = ContainerManager(
            parent: parent?.containerManager,
            swinjectContainer: _swinjectContainer,
            autoConfigureContainers: autoConfigureContainers
        )
        
        self.autoConfigureContainers = autoConfigureContainers
        preAssemble?(_swinjectContainer)
        self.serviceCollector = ServiceCollector(parent: parent?.serviceCollector)
        self._swinjectContainer.addBehavior(serviceCollector)
        let abstractRegistrations = self._swinjectContainer.registerAbstractContainer()

        // Expose the dependency tree for debugging
        let dependencyTree = builder.dependencyTree
        self._swinjectContainer.register(DependencyTree.self) { _ in dependencyTree }

        for assembly in builder.assemblies {
            assembly._assemble(containerManager: containerManager)
        }
        postAssemble?(_swinjectContainer)

        if overrideBehavior.useAbstractPlaceholders {
            for registration in abstractRegistrations.unfulfilledRegistrations {
                registration.registerPlaceholder(
                    container: _swinjectContainer,
                    errorFormatter: errorFormatter,
                    dependencyTree: dependencyTree
                )
            }
        } else {
            try abstractRegistrations.validate()
        }

        abstractRegistrations.reset()
        builder.releaseAssemblies()
    }

    func isRegistered<T: ModuleAssembly>(_ type: T.Type) -> Bool {
        return isRegistered(AssemblyReference(type))
    }

    // Return true if a module type has been registered into this container or the parent container
    func isRegistered(_ type: AssemblyReference) -> Bool {
        if let parent, parent.isRegistered(type) {
            return true
        }
        return builder.assemblyCache.contains(type)
    }

}

// Publicly expose the dependency tree so it can be used for debugging
public extension Swinject.Resolver {
    func _dependencyTree(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> DependencyTree {
        return knitUnwrap(resolve(DependencyTree.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
    }
}

public extension Knit.Resolver {
    func _dependencyTree() -> DependencyTree {
        self.unsafeResolver(file: #fileID, function: #function, line: #line)._dependencyTree()
    }
}

// MARK: -

private extension ModuleAssembly {

    @MainActor
    func _assemble(containerManager: ContainerManager) {
        let container = containerManager.get(TargetResolver.self)
        assemble(container: container)
    }

}
