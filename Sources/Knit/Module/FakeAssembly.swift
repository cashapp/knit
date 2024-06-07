//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation

/// An assembly that functions as a fake replacement for another
/// This type is designed to handle the base case for fake assemblies, for more complex cases use a standard ModuleAssembly
/// The following rules are applied:
/// * The FakeAssembly must use the same TargetResolver as the real assembly
/// * The real assembly must have a DefaultModuleAssemblyOverride setup pointing to this fake
/// * The FakeAssembly defaults to no dependencies to prevent expanding the DI graph
/// * The FakeAssembly is defined to replace the real assembly
public protocol FakeAssembly<ReplacedAssembly>: AutoInitModuleAssembly {
    associatedtype ReplacedAssembly: DefaultModuleAssemblyOverride where
        ReplacedAssembly.OverrideType == Self,
        ReplacedAssembly.TargetResolver == Self.TargetResolver
}

public extension FakeAssembly {

    static var replaces: [any ModuleAssembly.Type] { [ReplacedAssembly.self] }
    static var dependencies: [any ModuleAssembly.Type] { [] }
}
