//
// Copyright © Square, Inc. All rights reserved.
//

import Foundation

/// Class for building a list of module dependencies based on the dependency tree
final class DependencyBuilder {

    private var inputModules: [any ModuleAssembly] = []
    var assemblies: [any ModuleAssembly] = []
    let isRegisteredInParent: (any ModuleAssembly.Type) -> Bool
    private let defaultOverrides: DefaultOverrideState
    private var moduleSources: [String: any ModuleAssembly.Type] = [:]

    init(modules: [any ModuleAssembly],
         defaultOverrides: DefaultOverrideState = .whenTesting,
         isRegisteredInParent: ((any ModuleAssembly.Type) -> Bool)? = nil
    ) throws {
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
        moduleSources[String(describing: from)] = source
        let resolved = try resolvedType(from)
        guard !result.contains(where: {$0 == resolved}) else {
            return
        }
        // Add a source for both the original and the resolved types
        moduleSources[String(describing: resolved)] = source
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

    func sourcePath(moduleType: any ModuleAssembly.Type) -> [any ModuleAssembly.Type] {
        let name = String(describing: moduleType)
        guard let source = moduleSources[name] else {
            return [moduleType]
        }
        return sourcePath(moduleType: source) + [moduleType]
    }

    func sourcePathString(moduleType: any ModuleAssembly.Type) -> String {
        let modules = sourcePath(moduleType: moduleType).map { "\($0)"}.joined(separator: " -> ")
        return "Dependency path: \(modules)"
    }

}

extension DependencyBuilder {
    enum Error: LocalizedError {
        case moduleNotProvided(_ moduleType: any ModuleAssembly.Type, _ sourcePath: String)
        case invalidDefault(_ overrideType: any ModuleAssembly.Type, _ moduleType: any ModuleAssembly.Type)

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
                return "\(overrideType) used as default override does not implement \(moduleType)"
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