//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import Knit

// @knit internal
/// An assembly expected to be registered at the user level rather than at the app level
final class KnitExampleUserAssembly: ModuleAssembly {

    typealias TargetResolver = Resolver

    static var dependencies: [any ModuleAssembly.Type] { [] }

    func assemble(container: Container<TargetResolver>) {
        container.register(UserService.self) { _ in UserService() }
    }
}

final class UserService {

    var username: String = "John"
}
