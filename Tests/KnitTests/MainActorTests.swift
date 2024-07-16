//
// Copyright © Block, Inc. All rights reserved.
//

import Combine
import Swinject
import XCTest

private actor ActorA { }

/// A class confined to `@MainActor`
@MainActor
private class MainClassA { }

/// Declare a custom global actor, used below
@globalActor
private actor CustomGlobalActor: GlobalActor {
    
    static var shared = CustomGlobalActor()

    typealias ActorType = CustomGlobalActor

}

/// A class confined to a custom global actor. Means it must not be instantiated on the main thread.
@CustomGlobalActor
private class CustomGlobalActorClass {

    /// This initializer is confined to `@CustomGlobalActor` but has a dep that is `@MainActor` confined.
    init(mainClassA: MainClassA) {}

    func sayHello() -> String {
        "Hello"
    }

}

/// Consumes the above types
private class FinalConsumer {

    let actorA: ActorA

    let mainClassA: MainClassA

    /// The dependency here is on a future of CustomGlobalActorClass, not CustomGlobalActorClass itself
    let customGlobalActorClass: Future<CustomGlobalActorClass, Never>

    init(
        actorA: ActorA,
        mainClassA: MainClassA,
        customGlobalActorClass: Future<CustomGlobalActorClass, Never>
    ) {
        self.actorA = actorA
        self.mainClassA = mainClassA
        self.customGlobalActorClass = customGlobalActorClass
    }

    /// Needs to be an async function due to `@CustomGlobalActor` confinement
    func askCustomGlobalActorClassToSayHello() async -> String {
        await customGlobalActorClass.value.sayHello()
    }

}

private class TestAssembly: Assembly {

    func assemble(container: Container) {

        container.register(
            ActorA.self,
            factory: { resolver in
                MainActor.assumeIsolated {
                    return ActorA()
                }
            }
        )

        container.register(
            MainClassA.self,
            factory: { resolver in
                MainActor.assumeIsolated {
                    return MainClassA()
                }
            }
        )

        container.register(
            Future<CustomGlobalActorClass, Never>.self,
            factory: { resolver in
                MainActor.assumeIsolated {
                    let mainClassA = resolver.resolve(MainClassA.self)!

                    return Future<CustomGlobalActorClass, Never>() { promise in
                        Task {
                            let customGlobalActorClass = await CustomGlobalActorClass(
                                mainClassA: mainClassA
                            )
                            promise(.success(customGlobalActorClass))
                        }
                    }
                }
            }
        )

        container.register(
            FinalConsumer.self,
            factory: { resolver in
                MainActor.assumeIsolated {
                    let actorA = resolver.resolve(ActorA.self)!
                    let mainClassA = resolver.resolve(MainClassA.self)!
                    let customGlobalActorClass = resolver.resolve(Future<CustomGlobalActorClass, Never>.self)!
                    return FinalConsumer(actorA: actorA, mainClassA: mainClassA, customGlobalActorClass: customGlobalActorClass)
                }
            }
        )

    }
}

class MainActorTests: XCTestCase {

    func testAssembly() throws {
        let container = Container()
        TestAssembly().assemble(container: container)
        let finalConsumer = try XCTUnwrap(container.resolve(FinalConsumer.self))

        let asyncExpectation = expectation(description: "async task")

        Task {
            let result = await finalConsumer.askCustomGlobalActorClassToSayHello()
            XCTAssertEqual(result, "Hello")
            asyncExpectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }
}
