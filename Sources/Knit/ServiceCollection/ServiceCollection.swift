//
// Copyright © Block, Inc. All rights reserved.
//

/// Represents the aggregate of all services registered using ``Container/registerIntoCollection(_:factory:)``
/// or ``Container/autoregisterIntoCollection(_:initializer:)``.
public struct ServiceCollection<T> {
    public var entries: [T]
}
