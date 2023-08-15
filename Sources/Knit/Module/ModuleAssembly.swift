//
// Copyright © Square, Inc. All rights reserved.
//

import Foundation

public protocol ModuleAssembly: Assembly {

    associatedtype TargetResolver

    static var resolverType: Self.TargetResolver.Type { get }

    static var dependencies: [any ModuleAssembly.Type] { get }

    /// A ModuleAssembly can implement any number of other modules
    /// If this module implements another it is expected to provide all registrations that the base assembly supplies
    /// A common case is for a fake assembly that registers fake services from matching those from the original module
    /// The override is generally expected to live in a separate module so it can be imported just for tests
    static var implements: [any ModuleAssembly.Type] { get }

}

public extension ModuleAssembly {

    static var resolverType: Self.TargetResolver.Type {
        TargetResolver.self
    }

    static var implements: [any ModuleAssembly.Type] { [] }
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
    // Default the dependencies to using generatedDependencies
    public static var dependencies: [any ModuleAssembly.Type] { generatedDependencies }
}

public enum DefaultOverrideState {
    case on, off, whenTesting

    var allow: Bool {
        switch self {
        case .on: return true
        case .off: return false
        case .whenTesting: return Self.isRunningTests
        }
    }

    static var isRunningTests: Bool {
        // Will be true if XCTest.framework is included in the runtime.
        return NSClassFromString("XCTestCase") != nil
    }
}
