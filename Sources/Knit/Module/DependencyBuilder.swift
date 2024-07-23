//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation

/// Class for building a list of module dependencies based on the dependency tree
final class DependencyBuilder {

    private let assemblyValidation: ((any ModuleAssembly.Type) throws -> Void)?
    private var inputModules: [any ModuleAssembly] = []
    var assemblies: [any ModuleAssembly] = []
    let isRegisteredInParent: (AssemblyReference) -> Bool
    private let overrideBehavior: OverrideBehavior
    private(set) var dependencyTree: DependencyTree
    internal var assemblyCache = RegistrationCache()

    init(
        modules: [any ModuleAssembly],
        assemblyValidation: ((any ModuleAssembly.Type) throws -> Void)? = nil,
        overrideBehavior: OverrideBehavior = .defaultOverridesWhenTesting,
        isRegisteredInParent: ((AssemblyReference) -> Bool)? = nil
    ) throws {
        self.assemblyValidation = assemblyValidation
        self.overrideBehavior = overrideBehavior
        self.dependencyTree = .init(inputModules: modules)

        inputModules = modules
        self.isRegisteredInParent = isRegisteredInParent ?? {_ in false }

        // Gather a list of all dependencies needed in the tree
        for mod in modules {
            // Pass insertionPoint so that the tree gathered from later modules are instantiated later
            try gatherDependencies(
                from: AssemblyReference(type(of: mod)),
                insertionPoint: assemblyCache.assemblyList.count,
                source: nil
            )
        }

        let toAssemble = assemblyCache.toAssemble

        var inputLookup: [AssemblyReference: any ModuleAssembly] = [:]
        for module in modules {
            let ref = AssemblyReference(type(of: module))
            inputLookup[ref] = module
            for replaced in ref.type.replaces {
                inputLookup[AssemblyReference(replaced)] = module
            }
        }

        // Instantiate all types
        for ref in toAssemble {
            assemblies.append(try instantiate(moduleRef: ref, inputLookup: inputLookup))
        }
    }

    private func instantiate(
        moduleRef: AssemblyReference,
        inputLookup: [AssemblyReference: any ModuleAssembly]
    ) throws -> any ModuleAssembly {
        if let inputModule = inputLookup[moduleRef] {
            return inputModule
        }

        if let overrideType = try defaultOverride(moduleRef.type, fromInput: false),
           let autoInit = overrideType as? any AutoInitModuleAssembly.Type {
            return autoInit.init()
        }

        if let autoInit = moduleRef.type as? any AutoInitModuleAssembly.Type {
            return autoInit.init()
        }

        throw DependencyBuilderError.moduleNotProvided(
            moduleRef.type,
            dependencyTree.sourcePathString(moduleType: moduleRef.type)
        )
    }

    private func gatherDependencies(
        from: AssemblyReference,
        insertionPoint: Int,
        source: AssemblyReference?
    ) throws {
        if isRegisteredInParent(from) {
            return
        }

        // Add a source for the original type
        dependencyTree.add(assemblyType: from, source: source)

        // We've already seen this module, abort early
        if assemblyCache.seenCache.contains(from) {
            return
        }
        assemblyCache.seenCache.insert(from)
        let resolved = try resolvedType(from.type)
        let resolvedRef = AssemblyReference(resolved)

        // Assembly validation should be performed "up front"
        // For example if we are validating the assemblies' `TargetResolver`, we should not walk the tree
        // if the root assembly is targeting an incorrect resolver.
        if let assemblyValidation, !isRegisteredInParent(resolvedRef) {
            do {
                try assemblyValidation(resolved)
            } catch {
                throw DependencyBuilderError.assemblyValidationFailure(resolved, reason: error)
            }
        }

        guard !assemblyCache.contains(resolvedRef) else {
            return
        }

        // Add a source for the resolved type
        dependencyTree.add(assemblyType: resolvedRef, source: source)
        assemblyCache.insert(resolvedRef, insertionPoint: insertionPoint)
        for dep in getDependencies(resolved) {
            try gatherDependencies(
                from: AssemblyReference(dep),
                insertionPoint: insertionPoint,
                source: from
            )
        }
    }

    private func resolvedType(_ moduleType: any ModuleAssembly.Type) throws -> any ModuleAssembly.Type {
        let fromInput = inputModules.contains(where: { type(of: $0) == moduleType})
        return try defaultOverride(moduleType, fromInput: fromInput) ?? moduleType
    }

    private func getDependencies(_ moduleType: any ModuleAssembly.Type) -> [any ModuleAssembly.Type] {
        // Prevent a cycle where a module resolves via DefaultModuleAssemblyOverride
        return moduleType.combinedDependencies.filter { !moduleType.matches(moduleType: $0) }
    }

    private func defaultOverride(
        _ moduleType: any ModuleAssembly.Type,
        fromInput: Bool
    ) throws -> (any ModuleAssembly.Type)? {
        guard overrideBehavior.allowDefaultOverrides,
              !fromInput,
              let defaultType = (moduleType as? any DefaultModuleAssemblyOverride.Type)
        else {
            return nil
        }

        let type = defaultType.erasedType
        guard type.doesReplace(type: moduleType) else {
            throw DependencyBuilderError.invalidDefault(type, moduleType)
        }
        return type
    }
}

public enum DependencyBuilderError: LocalizedError {
    case moduleNotProvided(_ moduleType: any ModuleAssembly.Type, _ sourcePath: String)
    case invalidDefault(_ overrideType: any ModuleAssembly.Type, _ moduleType: any ModuleAssembly.Type)
    case assemblyValidationFailure(_ moduleType: any ModuleAssembly.Type, reason: Swift.Error)

    public var errorDescription: String? {
        switch self {
        case let .moduleNotProvided(moduleType, sourcePath):
            var testAdvice = ""
            if OverrideBehavior.isRunningTests {
                testAdvice += "Adding a dependency on the testing module for \(moduleType) should fix this issue"
            }
            return """
            Found module dependency: \(moduleType) that was not provided to assembler.
            \(sourcePath)
            \(testAdvice)
            """
        case let .invalidDefault(overrideType, moduleType):
            let suggestion = """
            SUGGESTED FIX:
            public static var replaces: [any ModuleAssembly.Type] {
                return [\(moduleType).self]
            }
            """
            return "\(overrideType) used as default override does not implement \(moduleType)\n\(suggestion)"
        case let .assemblyValidationFailure(moduleType, reason):
            return "\(moduleType) did not pass assembly validation check: \(reason.localizedDescription)"
        }
    }
}

private extension DefaultModuleAssemblyOverride {

    static var erasedType: any ModuleAssembly.Type {
        return OverrideType.self
    }
}

extension ModuleAssembly {
    static func matches(moduleType: any ModuleAssembly.Type) -> Bool {
        self == moduleType || doesReplace(type: moduleType)
    }

    static func doesReplace(type: any ModuleAssembly.Type) -> Bool {
        return replaces.contains(where: {$0 == type})
    }

    /// All original dependencies are registered along with any additional dependencies that the override requires
    static var combinedDependencies: [any ModuleAssembly.Type] {
        if OverrideBehavior.isRunningTests {
            // For tests only take this modules dependencies
            return Self.dependencies
        } else {
            // For app code, combine this modules dependencies and any dependencies from modules it replaces
            return Self.dependencies + Self.replaces.flatMap { $0.dependencies }
        }
    }

}

internal extension DependencyBuilder {

    struct RegistrationCache {
        var assemblyList: [AssemblyReference] = []
        var assemblySet: Set<AssemblyReference> = []
        var replacedAssemblies: Set<AssemblyReference> = []
        var seenCache: Set<AssemblyReference> = []

        func contains(_ ref: AssemblyReference) -> Bool {
            return assemblySet.contains(ref) || replacedAssemblies.contains(ref)
        }

        mutating func insert(_ assembly: AssemblyReference, insertionPoint: Int) {
            assemblyList.insert(assembly, at: insertionPoint)
            assemblySet.insert(assembly)
            assembly.type.replaces.forEach { replacedAssemblies.insert(.init($0)) }
        }

        var toAssemble: [AssemblyReference] {
            return assemblyList.filter { ref in
                // Collect AbstractAssemblies as they should all be instantiated and added to the container.
                // This needs to happen before the filter below as they are all expected to be implemented by other assemblies
                // and will therefore be filtered out.
                if ref.type is any AbstractAssembly.Type {
                    return true
                }

                // Filter out any types which have been replaced
                return !replacedAssemblies.contains(ref)
            }
        }
    }
}
