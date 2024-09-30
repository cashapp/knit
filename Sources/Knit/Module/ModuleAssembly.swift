//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import Swinject

public protocol ModuleAssembly {

    associatedtype TargetResolver

    static var resolverType: Self.TargetResolver.Type { get }

    static var dependencies: [any ModuleAssembly.Type] { get }

    @MainActor func assemble(container: Container)

    /// A ModuleAssembly can replace any number of other module assemblies.
    /// If this assembly replaces another it is expected to provide all registrations from the replaced assemblies.
    /// A common case is a fake assembly that registers fake services matching those from the original module.
    static var replaces: [any ModuleAssembly.Type] { get }

    /// Filter the list of dependencies down to those which match the scope of this assembly
    /// This can be overridden in apps with custom Resolver hierarchies
    static func scoped(_ dependencies: [any ModuleAssembly.Type]) -> [any ModuleAssembly.Type]

}

public extension ModuleAssembly {

    static var resolverType: Self.TargetResolver.Type {
        TargetResolver.self
    }

    static var replaces: [any ModuleAssembly.Type] { [] }

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
public struct OverrideBehavior {

    public let allowDefaultOverrides: Bool
    public let useAbstractPlaceholders: Bool

    public init(allowDefaultOverrides: Bool, useAbstractPlaceholders: Bool) {
        self.allowDefaultOverrides = allowDefaultOverrides
        self.useAbstractPlaceholders = useAbstractPlaceholders
    }

    /// Use any default overrides that are available.
    public static var useDefaultOverrides: Self {
        return .init(allowDefaultOverrides: true, useAbstractPlaceholders: true)
    }

    /// Disable and ignore any default overrides.
    /// Overrides that are _explicitly provided_ will still be used.
    public static var disableDefaultOverrides: Self {
        return .init(allowDefaultOverrides: false, useAbstractPlaceholders: false)
    }

    /// Use default overrides *based on the runtime context*.
    /// If the ModuleAssembler is running in a unit test environment, the default overrides will be used.
    /// Otherwise disable and ignore default overrides.
    public static var defaultOverridesWhenTesting: Self {
        return .init(allowDefaultOverrides: isRunningTests, useAbstractPlaceholders: isRunningTests)
    }

    static var isRunningTests: Bool {
        // Will be true if XCTest.framework is included in the runtime.
        return NSClassFromString("XCTestCase") != nil
    }
}
