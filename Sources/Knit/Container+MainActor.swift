//
// Copyright © Block, Inc. All rights reserved.
//

import Swinject

// This code should move into the Swinject library.
// There is an open pull request to make this change https://github.com/Swinject/Swinject/pull/570

extension Container {
    // Register a service type's factory with the assumption that the registration
    // will happen on the main thread.
    //
    // This method relies on the type eventually being resolved by a caller on the main
    // thread using the knit generated resolver. If that call is not made on the main
    // thread then a crash will occur.
    @discardableResult
    public func register<Service>(
        _ serviceType: Service.Type,
        name: String? = nil,
        mainActorFactory: @escaping @MainActor (Resolver) -> Service
    ) -> ServiceEntry<Service> {
        return register(serviceType, name: name) { r in
            MainActor.assumeIsolated {
                return mainActorFactory(r)
            }
        }
    }

    @discardableResult
    public func register<Service, Arg1>(
        _ serviceType: Service.Type,
        name: String? = nil,
        mainActorFactory: @escaping @MainActor (Resolver, Arg1) -> Service
    ) -> ServiceEntry<Service> {
        return register(serviceType) { (resolver: Resolver, arg1: Arg1) in
            MainActor.assumeIsolated {
                return mainActorFactory(resolver, arg1)
            }
        }
    }
}
