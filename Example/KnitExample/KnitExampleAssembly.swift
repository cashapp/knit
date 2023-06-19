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

        container.autoregisterIntoCollection(ExampleService.self, initializer: ExampleService.init)
    }

}

// MARK: - Example services

final class ExampleService {
    init() { }
}

final class ExampleArgumentService {
    init(string: String) {}
}
