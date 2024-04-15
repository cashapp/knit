//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation

public protocol KnitModule {
    
    /// The list of all assemblies contained in this module
    static var assemblies: [any ModuleAssembly.Type] { get }
    
    /// The list of modules that this module depends on
    static var moduleDependencies: [KnitModule.Type] { get }
}

public extension KnitModule {

    /// All known assemblies that are involved in this modules dependency graph
    static var allAssemblies: [any ModuleAssembly.Type] {
        return moduleDependencies.flatMap { $0.assemblies } + assemblies
    }
}
