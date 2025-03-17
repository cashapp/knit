//
//  Copyright © 2019 Swinject Contributors. All rights reserved.
//

/// This protocol is designed for the use to extend Swinject functionality.
/// Do NOT use this protocol unless you intend to write an extension or plugin to Swinject framework.
///
/// A type conforming Resolver protocol must conform _Resolver protocol too.
public protocol _Resolver {
    /// This method is designed for the use to extend Swinject functionality.
    /// Do NOT use this method unless you intend to write an extension or plugin to Swinject framework.
    ///
    /// - Parameter name: The registration name.
    /// - Parameter option: A service key option for an extension/plugin.
    /// - Parameter invoker: A closure to execute service resolution.
    ///     The primary responsibility of the invoker is to close over the values
    ///     of any arguments passed in during the resolve call.
    ///
    /// - Returns: The resolved service type instance, or nil if no service is found.
    // swiftlint:disable:next identifier_name
    func _resolve<Service, each Argument>(
        name: String?,
        option: ServiceKeyOption?,
        invoker: @escaping (Resolver, (Resolver, repeat each Argument) -> Any) -> Any
    ) -> Service?
}
