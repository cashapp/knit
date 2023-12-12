//
// Copyright © Square, Inc. All rights reserved.
//

import Foundation

/// Class for building a list of module dependencies based on the dependency tree
final class DependencyBuilder {

    private let assemblyValidation: ((any ModuleAssembly.Type) throws -> Void)?
    private var inputModules: [any ModuleAssembly] = []
    var assemblies: [any ModuleAssembly] = []
    let isRegisteredInParent: (any ModuleAssembly.Type) -> Bool
    private let defaultOverrides: DefaultOverrideState
    private var moduleSources: [String: any ModuleAssembly.Type] = [:]

    init(
        modules: [any ModuleAssembly],
        assemblyValidation: ((any ModuleAssembly.Type) throws -> Void)? = nil,
        defaultOverrides: DefaultOverrideState = .whenTesting,
        isRegisteredInParent: ((any ModuleAssembly.Type) -> Bool)? = nil
    ) throws {
        self.assemblyValidation = assemblyValidation
        self.defaultOverrides = defaultOverrides

        inputModules = modules
        self.isRegisteredInParent = isRegisteredInParent ?? {_ in false }

        // Gather a list of all dependencies needed in the tree
        var allModuleTypes: [any ModuleAssembly.Type] = []
        for mod in modules {
            // Pass insertionPoint so that the tree gathered from later modules are instantiated later
            try gatherDependencies(
                from: type(of: mod),
                insertionPoint: allModuleTypes.count,
                result: &allModuleTypes,
                source: nil
            )
        }
        let overrideTypes = allModuleTypes.filter { !$0.implements.isEmpty }

        // Filter out any types where an override was found
        allModuleTypes = allModuleTypes.filter { moduleType in
            return !overrideTypes.contains(where: {$0.doesImplement(type: moduleType)})
        }

        // Instantiate all types
        for type in allModuleTypes {
            guard !self.isRegisteredInParent(type) else {
                continue
            }
            assemblies.append(try instantiate(moduleType: type))
        }
    }

    private func instantiate(moduleType: any ModuleAssembly.Type) throws -> any ModuleAssembly {
        let inputModule = inputModules.first(where: { type(of: $0) == moduleType})
        let existingType = inputModules.first { assembly in
            return type(of: assembly).doesImplement(type: moduleType)
        }
        if let existingType {
            return existingType
        }
        if let overrideType = try defaultOverride(moduleType, fromInput: inputModule != nil),
           let autoInit = overrideType as? any AutoInitModuleAssembly.Type {
            return autoInit.init()
        }
        if let inputModule {
            return inputModule
        }
        if let autoInit = moduleType as? any AutoInitModuleAssembly.Type {
            return autoInit.init()
        }

        throw Error.moduleNotProvided(moduleType, sourcePathString(moduleType: moduleType))
    }

    private func gatherDependencies(
        from: any ModuleAssembly.Type,
        insertionPoint: Int,
        result: inout [any ModuleAssembly.Type],
        source: (any ModuleAssembly.Type)?
    ) throws {
        // Add a source for the original type
        let originalFromInput = inputModules.contains(where: { type(of: $0).matches(moduleType: from) })
        if !originalFromInput {
            moduleSources[String(describing: from)] = source
        }

        let resolved = try resolvedType(from)

        // Assembly validation should be performed "up front"
        // For example if we are validating the assemblies' `TargetResolver`, we should not walk the tree
        // if the root assembly is targeting an incorrect resolver.
        if let assemblyValidation, !isRegisteredInParent(resolved) {
            do {
                try assemblyValidation(resolved)
            } catch {
                throw DependencyBuilder.Error.assemblyValidationFailure(resolved, reason: error)
            }
        }

        guard !result.contains(where: {$0 == resolved}) else {
            return
        }
        // Add a source for the resolved type
        let resolvedFromInput = inputModules.contains(where: { type(of: $0).matches(moduleType: resolved) })
        if !resolvedFromInput {
            moduleSources[String(describing: resolved)] = source
        }

        result.insert(resolved, at: insertionPoint)
        for dep in getDependencies(resolved) {
            try gatherDependencies(
                from: dep,
                insertionPoint: insertionPoint,
                result: &result,
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
        guard defaultOverrides.allow,
              !fromInput,
              let defaultType = (moduleType as? any DefaultModuleAssemblyOverride.Type)
        else {
            return nil
        }

        let type = defaultType.erasedType
        guard type.doesImplement(type: moduleType) else {
            throw Error.invalidDefault(type, moduleType)
        }
        return type
    }

    private func buildSourcePath(moduleType: any ModuleAssembly.Type, path: inout [String]) {
        return buildSourcePath(moduleName: String(describing: moduleType), path: &path)
    }

    private func buildSourcePath(moduleName: String, path: inout [String]) {
        path.insert(moduleName, at: 0)
        guard let source = moduleSources[moduleName] else {
            return
        }

        // Prevent an infinite loop
        let sourceName = String(describing: source)
        if path.contains(sourceName) {
            return
        }
        return buildSourcePath(moduleType: source, path: &path)
    }

    func sourcePath(moduleType: any ModuleAssembly.Type) -> [String] {
        var path: [String] = []
        buildSourcePath(moduleType: moduleType, path: &path)
        return path
    }

    func sourcePath(moduleName: String) -> [String] {
        var path: [String] = []
        buildSourcePath(moduleName: moduleName, path: &path)
        return path
    }

    func sourcePathString(moduleName: String) -> String {
        let modules = sourcePath(moduleName: moduleName).joined(separator: " -> ")
        return "Dependency path: \(modules)"
    }

    func sourcePathString(moduleType: any ModuleAssembly.Type) -> String {
        return sourcePathString(moduleName: String(describing: moduleType))
    }

}

extension DependencyBuilder {
    enum Error: LocalizedError {
        case moduleNotProvided(_ moduleType: any ModuleAssembly.Type, _ sourcePath: String)
        case invalidDefault(_ overrideType: any ModuleAssembly.Type, _ moduleType: any ModuleAssembly.Type)
        case assemblyValidationFailure(_ moduleType: any ModuleAssembly.Type, reason: Swift.Error)

        var errorDescription: String? {
            switch self {
            case let .moduleNotProvided(moduleType, sourcePath):
                var testAdvice = ""
                if DefaultOverrideState.isRunningTests {
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
                public static var implements: [any ModuleAssembly.Type] {
                    return [\(moduleType).self]
                }
                """
                return "\(overrideType) used as default override does not implement \(moduleType)\n\(suggestion)"
            case let .assemblyValidationFailure(moduleType, reason):
                return "\(moduleType) did not pass assembly validation check: \(reason.localizedDescription)"
            }
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
        self == moduleType || doesImplement(type: moduleType)
    }

    static func doesImplement(type: any ModuleAssembly.Type) -> Bool {
        return implements.contains(where: {$0 == type})
    }

    /// All original dependencies are registered along with any additional dependencies that the override requires
    static var combinedDependencies: [any ModuleAssembly.Type] {
        if DefaultOverrideState.isRunningTests {
            // For tests only take this modules dependencies
            return Self.dependencies
        } else {
            // For app code, combine this modules dependencies and any dependencies from modules it implements
            return Self.dependencies + Self.implements.flatMap { $0.dependencies }
        }
    }

}
