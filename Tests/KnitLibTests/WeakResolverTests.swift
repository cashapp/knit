//
// Copyright © Square, Inc. All rights reserved.
//

import KnitLib
import XCTest

final class WeakResolverTests: XCTestCase {

    func test_weakResolver() {
        var container: Container? = Container()
        container?.register(String.self) { _ in "Test" }

        let weakResolver = WeakResolver(container: container!)

        XCTAssertEqual(weakResolver.resolve(String.self), "Test")
        XCTAssertTrue(weakResolver.isAvailable)
        XCTAssertNotNil(weakResolver.optionalResolver)
        XCTAssertNotNil(container?.optionalResolver)

        // Once the container is deallocated, the resolver is no longer available
        container = nil
        XCTAssertFalse(weakResolver.isAvailable)
        XCTAssertNil(weakResolver.optionalResolver)
    }

}

