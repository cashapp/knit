//
//  Copyright © 2021 Swinject Contributors. All rights reserved.
//

import Dispatch
import XCTest
@testable import Swinject

class SynchronizedResolverTests: XCTestCase {

    // MARK: Multiple threads

    func testSynchronizedResolverCanResolveCircularDependencies() {
        let container = SwinjectContainer { container in
            container.register(ParentProtocol.self) { _ in Parent() }
                .initCompleted { r, s in
                    let parent = s as! Parent
                    parent.child = r.resolve(ChildProtocol.self)
                }
                .inObjectScope(.graph)
            container.register(ChildProtocol.self) { _ in Child() }
                .initCompleted { r, s in
                    let child = s as! Child
                    child.parent = r.resolve(ParentProtocol.self)!
                }
                .inObjectScope(.graph)
        }

        onMultipleThreads {
            let parent = container.resolve(ParentProtocol.self) as! Parent
            let child = parent.child as! Child
            XCTAssert(child.parent === parent)
        }
    }

    func testSynchronizedResolverCanAccessParentAndChildContainersWithoutDeadlock() {
        let runInObjectScope = { (scope: ObjectScope) in
            let parentContainer = SwinjectContainer { container in
                container.register(Animal.self) { _ in Cat() }
                    .inObjectScope(scope)
            }
            let childResolver = SwinjectContainer(parent: parentContainer)
            // swiftlint:disable opening_brace
            onMultipleThreads(actions: [
                { _ = parentContainer.resolve(Animal.self) as! Cat },
                { _ = childResolver.resolve(Animal.self) as! Cat },
            ])
            // swiftlint:enable opening_brace
        }

        runInObjectScope(.transient)
        runInObjectScope(.graph)
        runInObjectScope(.container)
    }

    func testSynchronizedResolverUsesDistinctGraphIdentifier() {
        var graphs = Set<GraphIdentifier>()
        let container = SwinjectContainer {
            $0.register(Dog.self) {
                graphs.insert(($0 as! SwinjectContainer).currentObjectGraph!)
                return Dog()
            }
        }

        onMultipleThreads { _ = container.resolve(Dog.self) }

        XCTAssert(graphs.count == totalThreads)
    }
    
    func testSynchronizedResolverSynchronousReadsWrites() {
        let iterationCount = 3_000
        let container = SwinjectContainer()
        let registerExpectation = expectation(description: "register")
        let resolveExpectations = (0..<iterationCount).map { expectation(description: String(describing: $0)) }
        let resolutionLock = NSLock()

        DispatchQueue.global(qos: .background).async {
            for index in 0..<iterationCount {
                container.register(Animal.self, factory: { _ in
                    Cat(name: "\(index)")
                })
            }
            registerExpectation.fulfill()
        }
        
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.concurrentPerform(iterations: iterationCount) { (index) in
                _ = container.resolve(Animal.self)
                resolutionLock.lock()
                resolveExpectations[index].fulfill()
                resolutionLock.unlock()
            }
        }
        
        wait(for: [registerExpectation] + resolveExpectations, timeout: 3)
    }

    // MARK: Nested resolve

    func testSynchronizedResolverCanMakeItWithoutDeadlock() {
        let container = SwinjectContainer()
        let threadSafeResolver = container
        container.register(ChildProtocol.self) { _ in Child() }
        container.register(ParentProtocol.self) { _ in
            Parent(child: threadSafeResolver.resolve(ChildProtocol.self)!)
        }

        let queue = DispatchQueue(
            label: "SwinjectTests.SynchronizedContainerSpec.Queue", attributes: .concurrent
        )
        waitUntil(timeout: .seconds(2)) { done in
            queue.async {
                _ = threadSafeResolver.resolve(ParentProtocol.self)
                done()
            }
        }
    }

    // MARK: Wrapped type

    func testSynchronizedResolverSynchronizesProviderTypes() {
        var graphs = Set<GraphIdentifier>()
        let container = SwinjectContainer()
        container.register(Animal.self) {
            graphs.insert(($0 as! SwinjectContainer).currentObjectGraph!)
            return Dog()
        }

        onMultipleThreads {
            let lazy = container.resolve(Provider<Animal>.self)
            _ = lazy?.instance
        }

        XCTAssertEqual(graphs.count, totalThreads)
    }

    func testSynchronizedResolverSynchronizesLazyTypes() {
        // Lazy types might share graph identifiers and persistent entities.
        let container = SwinjectContainer()
        container.register(Dog.self) { _ in
            return Dog()
        }

        let queue = DispatchQueue(
            label: "SwinjectTests.SynchronizedContainerSpec.Queue", attributes: .concurrent
        )
        waitUntil(timeout: .seconds(2)) { done in
            queue.async {
                let lazy = container.resolve(Lazy<Dog>.self)
                _ = lazy?.instance
                done()
            }
        }
    }

    func testSynchronizedResolverSafelyDereferencesLazyTypes() {
        var graphs = Set<GraphIdentifier>()
        let container = SwinjectContainer()
        container.register(Animal.self) {
            graphs.insert(($0 as! SwinjectContainer).currentObjectGraph!)
            return Dog()
        }
        .inObjectScope(.container)

        // fast but roughly sufficient to trigger ARC-related crash
        for _ in 0..<200 {
            onMultipleThreads {
                // Lazy will be strongly referenced and then DE-referenced
                // which triggers a strong retain cycle on the GraphIdentifier
                // which may be simultaneously deallocated on a separate thread
                //
                // But, since the build with this test uses struct type for
                // the GraphIdentifier, this test will succeed. 🎉
                let lazy = container.resolve(Lazy<Animal>.self)
                _ = lazy?.instance
            }
        }
    }

    func testGraphIdentifierRestoredAfterLazyResolve() {
        let container = SwinjectContainer()
        container.register(LazilyResolvedProtocol.self) { _ in
            LazilyResolved()
        }
        container.register(LazySingletonProtocol.self) {
            let lazy = $0.resolve(Lazy<LazilyResolvedProtocol>.self)!
            return LazyChild(lazy: lazy)
        }
        .inObjectScope(.container)
        container.register(LazyChildProtocol.self) {
            let lazy = $0.resolve(Lazy<LazilyResolvedProtocol>.self)!
            return LazyChild(lazy: lazy)
        }
        container.register(LazyParentProtocol.self) {
            let child1 = $0.resolve(LazyChildProtocol.self)!
            let singleton = $0.resolve(LazySingletonProtocol.self)!
            // Previously, accessing instance here would permanently
            // hijack the graph identifier to the 'recalled' state.
            _ = singleton.lazy.instance
            let child2 = $0.resolve(LazyChildProtocol.self)!
            return LazyParent(child1: child1, child2: child2)
        }

        // Resolve, but don't access lazy value yet.
        _ = container.resolve(LazySingletonProtocol.self)!

        // First lazy value access in LazyParent resolve, this 
        // could've happened in its init or wherever.
        let parent = container.resolve(LazyParentProtocol.self)!

        XCTAssertIdentical(parent.child1, parent.child2)
        XCTAssertIdentical(parent.child1.lazy.instance, parent.child2.lazy.instance)
    }
}

private final class Counter {
    enum Status {
        case underMax, reachedMax
    }

    private var max: Int
    private let lock = DispatchQueue(label: "SwinjectTests.SynchronizedContainerSpec.Counter.Lock", attributes: [])
    var count = 0

    init(max: Int) {
        self.max = max
    }

    @discardableResult
    func increment() -> Status {
        var status = Status.underMax
        lock.sync {
            self.count += 1
            if self.count >= self.max {
                status = .reachedMax
            }
        }
        return status
    }
}

private let totalThreads = 500 // 500 threads are enough to get fail unless the container is thread safe.

private func onMultipleThreads(action: @escaping () -> Void) {
    onMultipleThreads(actions: [action])
}

private func onMultipleThreads(actions: [() -> Void]) {
    waitUntil(timeout: .seconds(2)) { done in
        let queue = DispatchQueue(
            label: "SwinjectTests.SynchronizedContainerTests.Queue",
            attributes: .concurrent
        )
        let counter = Counter(max: actions.count * totalThreads)
        for _ in 0 ..< totalThreads {
            actions.forEach { action in
                queue.async {
                    action()
                    if counter.increment() == .reachedMax {
                        done()
                    }
                }
            }
        }
    }
}

private func waitUntil(
    timeout: DispatchTimeInterval,
    action: @escaping (@escaping () -> Void) -> Void) {

    let group = DispatchGroup()
    group.enter()

    DispatchQueue.global().async {
        action {
            group.leave()
        }
    }

    _ = group.wait(timeout: .now() + timeout)
}
