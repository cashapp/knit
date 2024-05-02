//  Created by Alex Skorulis on 3/5/2024.

import Foundation
import Swinject
import XCTest

final class ContainerShadowingTests: XCTestCase {

    func test_noShadow() {
        let appContainer = Container()
        appContainer.register(Example.self) { _ in
            ProxyExample()
        }
        .inObjectScope(.container)

        let signedInContainer = Container(parent: appContainer)

        let example1 = appContainer.resolve(Example.self)!
        let example2 = signedInContainer.resolve(Example.self)!
        XCTAssertEqual(example1.value, example2.value)
    }

    func test_withShadow() {
        let appContainer = Container()
        appContainer.register(Dep.self) { _ in
            ProxyDep()
        }
        .inObjectScope(.container)

        appContainer.register(Example.self) { r in
            Example(dep: r.dep())
        }
        .inObjectScope(.container)

        let signedInContainer = Container(parent: appContainer)
        signedInContainer.register(Dep.self) { _ in
            RealDep()
        }
        .inObjectScope(.container)

        let example1 = appContainer.resolve(Example.self)!
        let example2 = signedInContainer.resolve(Example.self)!
        XCTAssertNotEqual(example1.value, example2.value)
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

private protocol Example {
    var dep: any Dep
}
