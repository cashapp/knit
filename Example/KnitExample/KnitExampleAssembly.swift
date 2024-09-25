//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import Knit

// @knit internal
final class KnitExampleAssembly: ModuleAssembly {
    
    typealias TargetResolver = Resolver

    static var dependencies: [any ModuleAssembly.Type] { [] }

    func assemble(container: Container) {
        container.addBehavior(ServiceCollector())

        container.autoregister(ExampleService.self, initializer: ExampleService.init)

        // @knit getter-named("example")
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

        container.register(ClosureService.self, name: "Test") { (resolver, arg1: @escaping () -> Void) in
            ClosureService(closure: arg1)
        }

        container.register(
            MainActorService.self,
            mainActorFactory: { _ in
                MainActorService()
            }
        )

        container.autoregisterIntoCollection(ExampleService.self, initializer: ExampleService.init)

        container.registerIntoCollection(
            MainActorService.self,
            factory: { _ in
                MainActorService()
            }
        )

        #if DEBUG
        container.autoregister(DebugService.self, initializer: DebugService.init)
        #endif
    }

    // Used to test #else statements being used outside of registrations
    static func exampleGatedFunction() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

}

// MARK: - Example services

final class NamedService {}

final class ExampleService {
    init() { }

    var title: String { "Example String" }
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

struct DebugService { }

@MainActor
final class MainActorService {
    init() { }

    var title: String { "Example String" }
}
