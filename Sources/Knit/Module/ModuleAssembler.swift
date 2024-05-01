//
// Copyright © Block, Inc. All rights reserved.
//

/// ModuleAssembler wraps the Swinject Assembler to resolves the full tree of module dependencies.
/// If dependencies are missing from the tree then the resolution will fail and indicate the missing module
public final class ModuleAssembler {

    let container: Container
    let parent: ModuleAssembler?
    let serviceCollector: ServiceCollector

    /// The resolver for this ModuleAssemblers container
    public let resolver: Resolver

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
    public convenience init(
        parent: ModuleAssembler? = nil,
        _ modules: [any Assembly],
        overrideBehavior: OverrideBehavior = .defaultOverridesWhenTesting,
        assemblyValidation: ((any ModuleAssembly.Type) throws -> Void)? = nil,
        errorFormatter: ModuleAssemblerErrorFormatter = DefaultModuleAssemblerErrorFormatter(),
        postAssemble: ((Container) -> Void)? = nil,
        file: StaticString = #file,
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
    required init(
        parent: ModuleAssembler? = nil,
        _modules modules: [any Assembly],
        overrideBehavior: OverrideBehavior = .defaultOverridesWhenTesting,
        assemblyValidation: ((any ModuleAssembly.Type) throws -> Void)? = nil,
        errorFormatter: ModuleAssemblerErrorFormatter = DefaultModuleAssemblerErrorFormatter(),
        postAssemble: ((Container) -> Void)? = nil
    ) throws {
        let moduleAssemblies = modules.compactMap { $0 as? any ModuleAssembly }
        let nonModuleAssemblies = modules.filter { !($0 is any ModuleAssembly) }

        self.builder = try DependencyBuilder(
            modules: moduleAssemblies,
            assemblyValidation: assemblyValidation,
            overrideBehavior: overrideBehavior,
            isRegisteredInParent: { type in
                return parent?.isRegistered(type) ?? false
            }
        )

        self.parent = parent
        self.container = Container(parent: parent?.container)
        self.serviceCollector = .init(parent: parent?.serviceCollector)
        self.container.addBehavior(serviceCollector)
        let abstractRegistrations = self.container.registerAbstractContainer()

        // Expose the dependency tree for debugging
        let dependencyTree = builder.dependencyTree
        self.container.register(DependencyTree.self) { _ in dependencyTree }

        let assembler = Assembler(container: self.container)
        assembler.apply(assemblies: nonModuleAssemblies)
        assembler.apply(assemblies: builder.assemblies)
        postAssemble?(container)
        
        if overrideBehavior.useAbstractPlaceholders {
            for registration in abstractRegistrations.unfulfilledRegistrations {
                registration.registerPlaceholder(
                    container: container,
                    errorFormatter: errorFormatter,
                    dependencyTree: dependencyTree
                )
            }
        } else {
            try abstractRegistrations.validate()
        }

        abstractRegistrations.reset()

        // https://github.com/Swinject/Swinject/blob/master/Documentation/ThreadSafety.md
        self.resolver = container.synchronize()
    }

    // Return true if a module type has been registered into this container or the parent container
    func isRegistered<T: ModuleAssembly>(_ type: T.Type) -> Bool {
        if let parent, parent.isRegistered(type) {
            return true
        }
        return registeredModules.contains(where: {$0.matches(moduleType: type)})
    }

}

// Publicly expose the dependency tree so it can be used for debugging
public extension Resolver {
    func _dependencyTree() -> DependencyTree {
        return knitUnwrap(resolve(DependencyTree.self))
    }
}
