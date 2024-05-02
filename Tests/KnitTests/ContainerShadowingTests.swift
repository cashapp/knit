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
        appContainer.register(Example.self) { _ in
            ProxyExample()
        }
        .inObjectScope(.container)

        let signedInContainer = Container(parent: appContainer)
        signedInContainer.register(Example.self) { _ in
            RealExample()
        }

        let example1 = appContainer.resolve(Example.self)!
        let example2 = signedInContainer.resolve(Example.self)!
        XCTAssertNotEqual(example1.value, example2.value)
    }
}

private protocol Example {
    var value: UUID { get }
}

private struct ProxyExample: Example {
    let value: UUID = UUID()
}

private struct RealExample: Example {
    let value: UUID = UUID()
}
