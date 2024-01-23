//
// Copyright © Block, Inc. All rights reserved.
//

import Knit
import XCTest

final class WeakResolverTests: XCTestCase {

    func test_weakResolver() {
        var container: Container? = Container()
        weak var weakContainer = container
        container?.register(String.self) { _ in "Test" }

        let weakResolver = WeakResolver(container: container!)

        XCTAssertEqual(weakResolver.resolve(String.self), "Test")
        XCTAssertTrue(weakResolver.isAvailable)
        XCTAssertNotNil(weakResolver.optionalResolver)
        XCTAssertNotNil(weakContainer)

        // Once the container is deallocated, the resolver is no longer available
        container = nil
        XCTAssertNil(weakContainer)
        XCTAssertFalse(weakResolver.isAvailable)
        XCTAssertNil(weakResolver.optionalResolver)
    }

    func test_optionalResolver_property() {
        // It is probably unusual if a consumer retains the result of the `optionalResolver` property,
        // but in case that happens we don't want to accidentally leak the container.

        var container: Container? = Container()
        weak var weakConatiner = container
        container?.register(String.self) { _ in "Test" }

        let weakResolver = WeakResolver(container: container!)

        // Holding the result of this property access should not retain the backing container
        let optionalResolver = weakResolver.optionalResolver

        container = nil
        XCTAssertNil(weakConatiner, "The container should be released")
        XCTAssertNotNil(optionalResolver)
        XCTAssertEqual(weakResolver.isAvailable, false, "`isAvailable` should return false")
    }

}

