//
// Copyright © Square, Inc. All rights reserved.
//

/// ModuleAssembler wraps the Swinject Assembler to resolves the full tree of module dependencies.
/// If dependencies are missing from the tree then the resolution will fail and indicate the missing module
public final class ModuleAssembler {

    let container: Container
    let parent: ModuleAssembler?

    /// The resolver for this ModuleAssemblers container
    public var resolver: Resolver {
        // https://github.com/Swinject/Swinject/blob/master/Documentation/ThreadSafety.md
        container.synchronize()
    }

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
        - defaultOverrides: Array of override types to use when resolving modules
        - postAssemble: Hook after all assemblies are registered to make changes to the container.

     */
    public init(
        parent: ModuleAssembler? = nil,
        _ modules: [any Assembly],
        defaultOverrides: DefaultOverrideState = .whenTesting,
        postAssemble: ((Container) -> Void)? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let moduleAssemblies = modules.compactMap { $0 as? any ModuleAssembly }
        let nonModuleAssemblies = modules.filter { !($0 is any ModuleAssembly) }
        // Hold an optional reference to be used by error handling later
        var createdBuilder: DependencyBuilder?
        do {
            self.builder = try DependencyBuilder(
                modules: moduleAssemblies,
                defaultOverrides: defaultOverrides
            ) { type in
                return parent?.isRegistered(type) ?? false
            }
            createdBuilder = self.builder

            self.parent = parent
            self.container = Container(parent: parent?.container)
            self.container.addBehavior(ServiceCollector())
            let abstractRegistrations = self.container.registerAbstractContainer()

            let assembler = Assembler(container: self.container)
            assembler.apply(assemblies: nonModuleAssemblies)
            assembler.apply(assemblies: builder.assemblies)
            postAssemble?(container)

            try abstractRegistrations.validate()
            abstractRegistrations.reset()
        } catch {
            let message = Self.formatErrors(dependencyBuilder: createdBuilder, error: error)
            fatalError(
                message,
                file: file,
                line: line
            )
        }
    }

    static func formatErrors(dependencyBuilder: DependencyBuilder?, error: Error) -> String {
        let info = "Error creating ModuleAssembler. Please make sure all necessary assemblies are provided."
        if let abstractErrors = error as? Container.AbstractRegistrationErrors, let builder = dependencyBuilder {
            let messages = abstractErrors.errors.map { abstractError in
                let assemblyName = abstractError.file.replacingOccurrences(of: ".swift", with: "")
                let path = builder.sourcePathString(moduleName: assemblyName)
                return "\(abstractError.localizedDescription)\n\(path)"
            }
            return "\(messages.joined(separator: "\n"))\n\(info)"
        } else {
            return "Error: \(error.localizedDescription)\(info)"
        }
    }

    // Return true if a module type has been registered into this container or the parent container
    func isRegistered<T: ModuleAssembly>(_ type: T.Type) -> Bool {
        if let parent, parent.isRegistered(type) {
            return true
        }
        return registeredModules.contains(where: {$0.matches(moduleType: type)})
    }

}
