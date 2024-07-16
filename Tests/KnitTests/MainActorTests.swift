//
// Copyright © Block, Inc. All rights reserved.
//

import Combine
import Swinject
import XCTest

private actor ActorA { 
    func sayHello() -> String {
        "Hello"
    }
}

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

/// A class that is async init but otherwise has sync methods.
private class AsyncInitClass {

    init() async {}

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

    var asyncInitClass: AsyncInitClass?

    private var cancellables = [AnyCancellable]()

    init(
        actorA: ActorA,
        mainClassA: MainClassA,
        customGlobalActorClass: Future<CustomGlobalActorClass, Never>,
        asyncInitClass: Future<AsyncInitClass, Never>
    ) {
        self.actorA = actorA
        self.mainClassA = mainClassA
        self.customGlobalActorClass = customGlobalActorClass

        asyncInitClass.sink { [weak self] result in
            self?.asyncInitClass = result
            // Can also inform other methods that this property is now available
        }.store(in: &cancellables)
    }

    /// Needs to be an async function due to `@CustomGlobalActor` confinement
    func askCustomGlobalActorClassToSayHello() async -> String {
        await customGlobalActorClass.value.sayHello()
    }

    func askActorAToSayHello() async -> String {
        await actorA.sayHello()
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
                        let customGlobalActorClass = await CustomGlobalActorClass(
                            mainClassA: mainClassA
                        )
                        promise(.success(customGlobalActorClass))
                    }
                }
            }
        )

        container.register(
            Future<AsyncInitClass, Never>.self,
            factory: { resolver in
                MainActor.assumeIsolated {
                    return Future<AsyncInitClass, Never>() { promise in
                        promise(.success(await AsyncInitClass()))
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
                    let asyncInitClass = resolver.resolve(Future<AsyncInitClass, Never>.self)!
                    return FinalConsumer(
                        actorA: actorA,
                        mainClassA: mainClassA,
                        customGlobalActorClass: customGlobalActorClass,
                        asyncInitClass: asyncInitClass
                    )
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
