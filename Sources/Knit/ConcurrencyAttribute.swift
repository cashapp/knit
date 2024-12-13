//
// Copyright © Block, Inc. All rights reserved.
//

/// The possible concurrency isolation for a registration.
public enum ConcurrencyAttribute {
    /// We do not currently have a way to forward this information through Swinject Behavior hooks
    /// so registrations that come from behaviors will be unknown.
    case unknown

    /// The default.
    case nonisolated

    /// Corresponds to the `@MainActor` attribute.
    case MainActor
}
