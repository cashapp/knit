//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import Knit
import KnitMacros

// @knit internal
final class KnitExampleAssembly: ModuleAssembly {
    
    typealias TargetResolver = BaseResolver

    static var dependencies: [any ModuleAssembly.Type] { [] }

    func assemble(container: Container<TargetResolver>) {
        container.register(ExampleService.self) { ExampleService.make(resolver: $0) }

        // @knit alias("example")
        container.register(ExampleArgumentService.self) { (_, arg: String) in
            ExampleArgumentService.init(string: arg)
        }

        container.register(ExampleArgumentService.self) { (resolver: Resolver, argument: ExampleArgumentService.Argument) in
            ExampleArgumentService(arg: argument)
        }

        container.register(NamedService.self, name: "name") { _ in NamedService() }

        container.register(ClosureService.self) { (resolver: Resolver, closure: @escaping (() -> Void)) in
            ClosureService(closure: closure)
        }

        container.register(ClosureService.self, name: "Test") { (resolver, arg1: @escaping () -> Void) in
            ClosureService(closure: arg1)
        }

        container.register(
            MainActorService.self,
            mainActorFactory: { _ in
                MainActorService()
            }
        )

        container.registerIntoCollection(ExampleService.self) { ExampleService.make(resolver: $0) }

        container.registerIntoCollection(
            MainActorService.self,
            factory: { _ in
                MainActorService()
            }
        )

        #if DEBUG
        container.register(DebugService.self) { _ in DebugService() }
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

    @Resolvable<Resolver>
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
