//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import Swinject

public protocol ModuleAssembly: Assembly {

    associatedtype TargetResolver

    static var resolverType: Self.TargetResolver.Type { get }

    static var dependencies: [any ModuleAssembly.Type] { get }

    /// A ModuleAssembly can implement any number of other modules' assemblies.
    /// If this module implements another it is expected to provide all registrations that the implemented assemblies supply.
    /// A common case is for an "implementation" assembly to fulfill all the abstract registrations from an AbstractAssembly.
    /// Similarly, another common case is a fake assembly that registers fake services matching those from the original module.
    static var implements: [any ModuleAssembly.Type] { get }

    /// Filter the list of dependencies down to those which match the scope of this assembly
    /// This can be overridden in apps with custom Resolver hierarchies
    static func scoped(_ dependencies: [any ModuleAssembly.Type]) -> [any ModuleAssembly.Type]

}

public extension ModuleAssembly {

    static var resolverType: Self.TargetResolver.Type {
        TargetResolver.self
    }

    static var implements: [any ModuleAssembly.Type] { [] }

    static func scoped(_ dependencies: [any ModuleAssembly.Type]) -> [any ModuleAssembly.Type] {
        return dependencies.filter {
            // Default the scoped implementation to match types directly
            return self.resolverType == $0.resolverType
        }
    }
}

/// A ModuleAssembly that can be initialised without any parameters
public protocol AutoInitModuleAssembly: ModuleAssembly {
    init()
}

/// Defines that a base module should by default be overridden by another type in tests
/// This allows simply importing the test assembly to then be automatically inserted
public protocol DefaultModuleAssemblyOverride: ModuleAssembly {
    associatedtype OverrideType: AutoInitModuleAssembly
}

/// Defines the fields for a module assembly that can be automatically generated
public protocol GeneratedModuleAssembly: ModuleAssembly {
    static var generatedDependencies: [any ModuleAssembly.Type] { get }
}

extension ModuleAssembly where Self: GeneratedModuleAssembly {
    // Default the dependencies to using generatedDependencies scoped to those with compatible resolvers
    public static var dependencies: [any ModuleAssembly.Type] { scoped(generatedDependencies) }
}

/// Control the behavior of Assembly Overrides.
public enum OverrideBehavior {

    /// Use any default overrides that are available.
    case useDefaultOverrides

    /// Disable and ignore any default overrides.
    /// Overrides that are _explicitly provided_ will still be used.
    case disableDefaultOverrides

    /// Use default overrides *based on the runtime context*.
    /// If the ModuleAssembler is running in a unit test environment, the default overrides will be used.
    /// Otherwise disable and ignore default overrides.
    case defaultOverridesWhenTesting

    var allowDefaultOverrides: Bool {
        switch self {
        case .useDefaultOverrides: return true
        case .disableDefaultOverrides: return false
        case .defaultOverridesWhenTesting: return Self.isRunningTests
        }
    }

    static var isRunningTests: Bool {
        // Will be true if XCTest.framework is included in the runtime.
        return NSClassFromString("XCTestCase") != nil
    }
}
