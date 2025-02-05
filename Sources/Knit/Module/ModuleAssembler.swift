//
// Copyright © Block, Inc. All rights reserved.
//

/// ModuleAssembler wraps the Swinject Assembler to resolves the full tree of module dependencies.
/// If dependencies are missing from the tree then the resolution will fail and indicate the missing module
public final class ModuleAssembler {

    /// The container that registrations have been placed in. Prefer using resolver unless mutable access is required
    let _container: Container
    let parent: ModuleAssembler?
    let serviceCollector: ServiceCollector

    /// The resolver for this ModuleAssemblers container
    public var resolver: Resolver { _container }

    // Module types that were registered into the container owned by this ModuleAssembler
    var registeredModules: [any ModuleAssembly.Type] {
        builder.assemblies.map { type(of: $0) }
    }

    let builder: DependencyBuilder

    /** The created ModuleAssembler will create a `Container` which references the optional parent.
     A depth first search will find all dependencies which will be registered

     - Parameters:
        - parent: A ModuleAssembler that has already been setup with some dependencies.
        - modules: Array of modules to register
        - overrideBehavior: Behavior of default override usage.
        - assemblyValidation: An optional closure to perform custom validation on module assemblies for this assembler.
            The Assembler will invoke this closure with each ModuleAssembly.Type as it performs its initialization.
            If the closure throws an error for any of the assemblies then a fatal error will occur.
        - postAssemble: Hook after all assemblies are registered to make changes to the container.
     */
    @MainActor public convenience init(
        parent: ModuleAssembler? = nil,
        _ modules: [any ModuleAssembly],
        overrideBehavior: OverrideBehavior = .defaultOverridesWhenTesting,
        assemblyValidation: ((any ModuleAssembly.Type) throws -> Void)? = nil,
        errorFormatter: ModuleAssemblerErrorFormatter = DefaultModuleAssemblerErrorFormatter(),
        postAssemble: ((Container) -> Void)? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        // Hold an optional reference to be used by error handling later
        var createdBuilder: DependencyBuilder?
        do {
            try self.init(
                parent: parent,
                _modules: modules,
                overrideBehavior: overrideBehavior,
                assemblyValidation: assemblyValidation,
                errorFormatter: errorFormatter,
                postAssemble: postAssemble
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
        postAssemble: ((Container) -> Void)? = nil
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
        self._container = Container(
            parent: parent?._container,
            behaviors: behaviors
        )
        self.serviceCollector = .init(parent: parent?.serviceCollector)
        self._container.addBehavior(serviceCollector)
        let abstractRegistrations = self._container.registerAbstractContainer()

        // Expose the dependency tree for debugging
        let dependencyTree = builder.dependencyTree
        self._container.register(DependencyTree.self) { _ in dependencyTree }

        for assembly in builder.assemblies {
            assembly.assemble(container: self._container)
        }
        postAssemble?(_container)

        if overrideBehavior.useAbstractPlaceholders {
            for registration in abstractRegistrations.unfulfilledRegistrations {
                registration.registerPlaceholder(
                    container: _container,
                    errorFormatter: errorFormatter,
                    dependencyTree: dependencyTree
                )
            }
        } else {
            try abstractRegistrations.validate()
        }

        abstractRegistrations.reset()
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
public extension Resolver {
    func _dependencyTree(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> DependencyTree {
        return knitUnwrap(resolve(DependencyTree.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
    }
}
