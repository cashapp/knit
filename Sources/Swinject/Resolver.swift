//
//  Created by Yoichi Tagaya on 8/18/15.
//  Copyright © 2019 Swinject Contributors. All rights reserved.
//

//
// NOTICE:
//
// Resolver.swift is generated from Resolver.erb by ERB.
// Do NOT modify Container.Arguments.swift directly.
// Instead, modify Resolver.erb and run `Scripts/gencode` at the project root directory to generate the code.
//


public protocol Resolver {
    func resolve<Service, each Argument>(
        _ serviceType: Service.Type,
        name: String?,
        arguments: repeat each Argument
    ) -> Service?

    // This additional resolve function is a workaround a bug in the swift compiler
    // without it the compiler will crash (tested in Xcode 16.2)
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
