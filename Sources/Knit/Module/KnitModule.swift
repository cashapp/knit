//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation

public protocol KnitModule {
    
    /// The list of all assemblies contained in this module
    static var assemblies: [any ModuleAssembly.Type] { get }
}
