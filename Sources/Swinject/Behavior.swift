//
//  Copyright © 2019 Swinject Contributors. All rights reserved.
//

/// Protocol for adding functionality to the container
public protocol Behavior {
    /// Whether the container should report resolutions to this Behavior.
    /// If `true`, `container(_:didResolve:name:)` will be called after each successful resolution.
    /// Defaults to `false`.
    var shouldReportResolution: Bool { get }

    /// This will be invoked on each behavior added to the `container` for each `entry` added to the container using
    /// one of the `register()` or type forwarding methods
    ///
    /// - Parameters:
    ///     - container: container into which an `entry` has been registered
    ///     - type: Type which will be resolved using the `entry`
    ///     - entry: ServiceEntry registered to the `container`
    ///     - name: name under which the service has been registered to the `container`
    ///
    /// - Remark: `Type` and `Service` can be different types in the case of type forwarding (commonly used as `.implements()`).
    /// `Type` will represent the forwarded type key, and `Service` will represent the destination.
    func container<Type, Service>(
        _ container: SwinjectContainer,
        didRegisterType type: Type.Type,
        toService entry: ServiceEntry<Service>,
        withName name: String?
    )

    /// This will be invoked after a successful resolution if `shouldReportResolution` is `true`.
    ///
    /// - Parameters:
    ///     - container: container from which the service was resolved
    ///     - serviceType: The type that was resolved
    ///     - name: The registration name used for resolution (if any)
    ///     - duration: The time taken to resolve the service
    func container<Service>(
        _ container: SwinjectContainer,
        didResolve serviceType: Service.Type,
        name: String?,
        duration: Duration
    )
}

// MARK: - Default Implementations

public extension Behavior {
    var shouldReportResolution: Bool { false }

    func container<Service>(
        _ container: SwinjectContainer,
        didResolve serviceType: Service.Type,
        name: String?,
        duration: Duration
    ) {}
}
