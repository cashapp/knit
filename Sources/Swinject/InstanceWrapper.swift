//
//  Copyright © 2019 Swinject Contributors. All rights reserved.
//

protocol InstanceWrapper {
    static var wrappedType: Any.Type { get }
    init?(inContainer container: SwinjectContainer, withInstanceFactory factory: ((GraphIdentifier?) -> Any?)?)
}

extension Optional: InstanceWrapper {
    static var wrappedType: Any.Type { return Wrapped.self }

    init?(inContainer _: SwinjectContainer, withInstanceFactory factory: ((GraphIdentifier?) -> Any?)?) {
        self = factory?(.none) as? Wrapped
    }
}
