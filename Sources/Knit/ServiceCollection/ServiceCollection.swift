//
// Copyright © Block, Inc. All rights reserved.
//

/// Represents the aggregate of all services registered using ``Container/registerIntoCollection(_:factory:)``
/// or ``Container/autoregisterIntoCollection(_:initializer:)``.
public struct ServiceCollection<T> {
    
    // Box the parent in an array to remove issues of a recursive memory layout
    // This array will only have 0 or 1 element
    private let parent: [ServiceCollection<T>]
    
    /// Entries that were registered into the ServiceCollector in the current container
    public let entries: [T]
    
    /// All entries from this and any parent containers
    public var allEntries: [T] {
        entries + parent.flatMap { $0.allEntries }
    }
    
    public init(parent: ServiceCollection<T>?, entries: [T]) {
        self.parent = parent.map { [$0] } ?? []
        self.entries = entries
    }
}
