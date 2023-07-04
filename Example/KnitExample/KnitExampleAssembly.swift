// Copyright © Square, Inc. All rights reserved.

import Foundation
import Knit

final class KnitExampleAssembly: Assembly {

    func assemble(container: Container) {
        container.addBehavior(ServiceCollector())

        container.autoregister(ExampleService.self, initializer: ExampleService.init)

        container.register(ExampleArgumentService.self) { (_, arg: String) in
            ExampleArgumentService.init(string: arg)
        }

        container.autoregister(
            ExampleArgumentService.self,
            argument: ExampleArgumentService.Argument.self,
            initializer: ExampleArgumentService.init(arg:)
        )

        container.autoregister(NamedService.self, name: "name", initializer: NamedService.init)

        container.autoregister(ClosureService.self, argument: (() -> Void).self, initializer: ClosureService.init)

        container.autoregisterIntoCollection(ExampleService.self, initializer: ExampleService.init)
    }

}

// MARK: - Example services

final class NamedService {}

final class ExampleService {
    init() { }
}

final class ExampleArgumentService {
    init(string: String) {}
    struct Argument {
        let string: String
    }

    convenience init(arg: Argument) {
        self.init(string: arg.string)
    }
}

final class ClosureService {

    init(closure: @escaping (() -> Void)) { }
}
