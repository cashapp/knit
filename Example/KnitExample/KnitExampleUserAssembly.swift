//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import Knit

// @knit internal
/// An assembly expected to be registered at the user level rather than at the app level
final class KnitExampleUserAssembly: Assembly {

    func assemble(container: Container) {
        container.autoregister(UserService.self, initializer: UserService.init)
    }
}

final class UserService {

    var username: String = "John"
}
