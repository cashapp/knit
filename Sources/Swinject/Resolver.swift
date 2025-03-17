//
//  Created by Yoichi Tagaya on 8/18/15.
//  Copyright © 2019 Swinject Contributors. All rights reserved.
//

public protocol Resolver {

    /// Retrieves the instance with the specified service type and list of arguments to the factory closure.
    ///
    /// - Parameters:
    ///   - serviceType: The service type to resolve.
    ///   - arguments:   List of arguments to pass to the factory closure.
    ///
    /// - Returns: The resolved service type instance, or nil if no registration for the service type
    ///            and list of arguments is found.
    func resolve<Service, each Argument>(
        _ serviceType: Service.Type,
        name: String?,
        arguments: repeat each Argument
    ) -> Service?

    // This additional resolve function is a workaround a bug in the swift compiler
    // without it the compiler will crash (tested in Xcode 16.2)

    /// Retrieves the instance with the specified service type.
    ///
    /// - Parameter serviceType: The service type to resolve.
    ///
    /// - Returns: The resolved service type instance, or nil if no service is found.
    func resolve<Service>(_ serviceType: Service.Type, name: String?) -> Service?

}

public extension Resolver {
    func resolve<Service, each Argument>(
        _ serviceType: Service.Type,
        arguments: repeat each Argument
    ) -> Service? {
        return self.resolve(serviceType, name: nil, arguments: repeat each arguments)
    }

    func resolve<Service>(_ serviceType: Service.Type) -> Service? {
        return self.resolve(serviceType, name: nil)
    }
}
