//
//  Copyright © 2019 Swinject Contributors. All rights reserved.
//

protocol InstanceWrapper {
    static var wrappedType: Any.Type { get }
    init?(inContainer container: Container, withInstanceFactory factory: ((GraphIdentifier?) -> Any?)?)
}

extension Optional: InstanceWrapper {
    static var wrappedType: Any.Type { return Wrapped.self }

    init?(inContainer _: Container, withInstanceFactory factory: ((GraphIdentifier?) -> Any?)?) {
        self = factory?(.none) as? Wrapped
    }
}
