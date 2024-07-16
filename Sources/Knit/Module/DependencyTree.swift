//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation

/// Storage for details of how the dependency tree was constructed
public struct DependencyTree: CustomDebugStringConvertible {

    // Assemblies that were originally provided to create the tree
    private let inputModules: [AssemblyReference]
    
    // List of all registered modules
    private var allModules: Set<AssemblyReference>

    // List of how each module was pulled into the graph
    private var moduleSources: [AssemblyReference: AssemblyReference] = [:]

    init(inputModules: [any ModuleAssembly]) {
        self.inputModules = inputModules.map { AssemblyReference(type(of: $0)) }
        allModules = Set(self.inputModules)
    }

    mutating func add(
        assemblyType: any ModuleAssembly.Type,
        source: (any ModuleAssembly.Type)?
    ) {
        let fromInputs = inputModules.contains(where: { $0.type == assemblyType })
        let typeReference = AssemblyReference(assemblyType)
        if let source, !fromInputs && moduleSources[typeReference] == nil {
            moduleSources[typeReference] = AssemblyReference(source)
        }
        allModules.insert(typeReference)
    }

    // MARK: - Public API

    public func sourcePath(moduleName: String) -> [String] {
        guard let match = allModules.first(where: { $0.name == moduleName}) else {
            return ["** Knit: Could not find module \(moduleName) **"]
        }
        return sourcePath(moduleType: match.type)
    }

    public func sourcePath(moduleType: any ModuleAssembly.Type) -> [String] {
        var path: [String] = []
        buildSourcePath(moduleName: AssemblyReference(moduleType), path: &path)
        return path
    }

    public var debugDescription: String {
        return inputModules.flatMap { debugDescription(assemblyRef: $0, indent: "") }.joined(separator: "\n")
    }

    public func dumpGraph() {
        print("Dependency Graph:\n\(debugDescription)")
    }

    // MARK: - Private Methods

    private func buildSourcePath(moduleName: AssemblyReference, path: inout [String]) {
        path.insert(moduleName.name, at: 0)
        guard let source = moduleSources[moduleName] else {
            return
        }

        // Prevent an infinite loop
        if path.contains(source.name) {
            return
        }
        return buildSourcePath(moduleName: source, path: &path)
    }

    private func debugDescription(assemblyRef: AssemblyReference, indent: String) -> [String] {
        let children = moduleSources.filter { key, value in
            return value == assemblyRef
        }.keys.sorted(by: { $0.name < $1.name })
        let hasDash = indent.firstIndex(of: "-") != nil
        let newIndent = hasDash ? "  \(indent)" : "  - \(indent)"
        let childRows = children.flatMap { debugDescription(assemblyRef: $0, indent: newIndent) }

        var selfRow = "\(indent)\(assemblyRef.name)"
        let replacements = findReplacements(assemblyRef: assemblyRef).map { $0.name }.joined(separator: ", ")
        if !replacements.isEmpty {
            selfRow += " (\(replacements))"
        }

        return [selfRow] + childRows
    }

    private func findReplacements(assemblyRef: AssemblyReference) -> [AssemblyReference] {
        return allModules.filter { $0.type.doesReplace(type: assemblyRef.type) && $0 != assemblyRef}
    }

    public func sourcePathString(moduleName: String) -> String {
        let modules = sourcePath(moduleName: moduleName).joined(separator: " -> ")
        return "Dependency path: \(modules)"
    }

    public func sourcePathString(moduleType: any ModuleAssembly.Type) -> String {
        return sourcePathString(moduleName: String(describing: moduleType))
    }
}

/// Wrapper for the types to allow them to be hashable
private struct AssemblyReference: Hashable {

    let type: any ModuleAssembly.Type
    let id: ObjectIdentifier

    var name: String { String(describing: type) }

    init(_ type: any ModuleAssembly.Type) {
        self.type = type
        self.id = ObjectIdentifier(type)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AssemblyReference, rhs: AssemblyReference) -> Bool {
        return lhs.type == rhs.type
    }

}
