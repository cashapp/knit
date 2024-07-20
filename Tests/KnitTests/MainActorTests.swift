//
// Copyright © Block, Inc. All rights reserved.
//

import Combine
import Knit
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

private final class TestAssembly: AutoInitModuleAssembly {

    typealias TargetResolver = TestResolver

    func assemble(container: Container<TargetResolver>) {

        container.register(
            ActorA.self,
            mainActorFactory: { @MainActor resolver in
                ActorA()
            }
        )

        container.register(
            MainClassA.self,
            mainActorFactory: { @MainActor resolver in
                MainClassA()
            }
        )

        container.register(
            Future<CustomGlobalActorClass, Never>.self,
            mainActorFactory: { @MainActor resolver in
                let mainClassA = resolver.unsafeResolver.resolve(MainClassA.self)!

                return Future<CustomGlobalActorClass, Never>() { promise in
                    let customGlobalActorClass = await CustomGlobalActorClass(
                        mainClassA: mainClassA
                    )
                    promise(.success(customGlobalActorClass))
                }
            }
        )

        container.register(
            Future<AsyncInitClass, Never>.self,
            mainActorFactory: { @MainActor resolver in
                return Future<AsyncInitClass, Never>() { promise in
                    promise(.success(await AsyncInitClass()))
                }
            }
        )

        container.register(
            FinalConsumer.self,
            mainActorFactory: { @MainActor resolver in
                let actorA = resolver.unsafeResolver.resolve(ActorA.self)!
                let mainClassA = resolver.unsafeResolver.resolve(MainClassA.self)!
                let customGlobalActorClass = resolver.unsafeResolver.resolve(Future<CustomGlobalActorClass, Never>.self)!
                let asyncInitClass = resolver.unsafeResolver.resolve(Future<AsyncInitClass, Never>.self)!
                return FinalConsumer(
                    actorA: actorA,
                    mainClassA: mainClassA,
                    customGlobalActorClass: customGlobalActorClass,
                    asyncInitClass: asyncInitClass
                )
            }
        )

    }

    init() {}

    static var dependencies: [any Knit.ModuleAssembly.Type] { [] }

}

class MainActorTests: XCTestCase {

    @MainActor
    func testAssembly() throws {
        let assembler = ModuleAssembler(
            [TestAssembly()]
        )
        let finalConsumer = try XCTUnwrap(assembler.resolver.resolve(FinalConsumer.self))

        let asyncExpectation = expectation(description: "async task")

        Task {
            let result = await finalConsumer.askCustomGlobalActorClassToSayHello()
            XCTAssertEqual(result, "Hello")
            asyncExpectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }
}
