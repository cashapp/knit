//  Created by Alex Skorulis on 3/5/2024.

import Foundation
import Swinject
import SwinjectAutoregistration
import XCTest

final class ContainerShadowingTests: XCTestCase {

    func test_noShadow() {
        let appContainer = Container()
        appContainer.register(Dep.self) { _ in
            ProxyDep()
        }
        .inObjectScope(.container)

        let signedInContainer = Container(parent: appContainer)

        let dep1 = appContainer.resolve(Dep.self)!
        let dep2 = signedInContainer.resolve(Dep.self)!
        XCTAssertEqual(dep1.value, dep2.value)
    }
    
    // Shadowing dependencies while using a single Example registration
    func test_dependencyShadow() {
        let appContainer = Container()
        appContainer.autoregister(Dep.self, initializer: ProxyDep.init)
            .inObjectScope(.container)
        appContainer.autoregister(Example.self, initializer: Example.init)
            .inObjectScope(.container)

        let signedInContainer = Container(parent: appContainer)
        signedInContainer.autoregister(Dep.self, initializer: RealDep.init)
            .inObjectScope(.container)

        let dep1 = appContainer.resolve(Dep.self)!
        let dep2 = signedInContainer.resolve(Dep.self)!
        XCTAssertNotEqual(dep1.value, dep2.value)

        // DANGER: Changing the order of these calls will change which Dep gets used
        let example1 = appContainer.resolve(Example.self)!
        let example2 = signedInContainer.resolve(Example.self)!

        XCTAssertEqual(example1.dep.value, example2.dep.value)

        XCTAssertEqual(example1.dep.value, dep1.value)
        XCTAssertEqual(example2.dep.value, dep1.value)
    }
    
    func test_exampleShadow() {
        let appContainer = Container()
        appContainer.autoregister(Dep.self, initializer: ProxyDep.init)
            .inObjectScope(.container)
        appContainer.autoregister(Example.self, initializer: Example.init)
            .inObjectScope(.container)

        let signedInContainer = Container(parent: appContainer)
        signedInContainer.autoregister(Dep.self, initializer: RealDep.init)
            .inObjectScope(.container)
        signedInContainer.autoregister(Example.self, initializer: Example.init)
            .inObjectScope(.container)

        let dep1 = appContainer.resolve(Dep.self)!
        let dep2 = signedInContainer.resolve(Dep.self)!
        XCTAssertNotEqual(dep1.value, dep2.value)

        // Changing the order will still yield the expected result
        let example1 = appContainer.resolve(Example.self)!
        let example2 = signedInContainer.resolve(Example.self)!

        XCTAssertNotEqual(example1.dep.value, example2.dep.value)

        XCTAssertEqual(example1.dep.value, dep1.value)
        XCTAssertEqual(example2.dep.value, dep2.value)
    }
}

private protocol Dep {
    var value: UUID { get }
}

private struct ProxyDep: Dep {
    let value: UUID = UUID()
}

private struct RealDep: Dep {
    let value: UUID = UUID()
}

private struct Example {
    let dep: Dep
}
