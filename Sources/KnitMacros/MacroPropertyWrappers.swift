//  Created by Alex Skorulis on 23/1/2025.

import Foundation

/// Defines that the parameter should be resolved using the provided name
/// The property wrapper is only used as a hint to the Resolvable macro and has no effect outside of the macro
@propertyWrapper
public struct Named<Value> {
    public var wrappedValue: Value

    public init(wrappedValue: Value, _ name: String) {
        self.wrappedValue = wrappedValue
    }
}

/// Defines that the parameter should not be resolved from the DI graph but should be an argument
/// The property wrapper is only used as a hint to the Resolvable macro and has no effect outside of the macro
@propertyWrapper
public struct Argument<Value> {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}

/// Defines that the parameter should not be resolved from the DI graph but should use the default value provided
/// The property wrapper is only used as a hint to the Resolvable macro and has no effect outside of the macro
@propertyWrapper
public struct UseDefault<Value> {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}
