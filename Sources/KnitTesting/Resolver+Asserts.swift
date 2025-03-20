//
// Copyright © Block, Inc. All rights reserved.
//

import Knit
import Swinject
import XCTest

public extension Swinject.Resolver {

    func assertTypeResolved<T>(
        _ result: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNotNil(
            result,
            """
            The container did not resolve the type: \(T.self). Check that this type is registered correctly.
            Dependency Graph:
            \(_dependencyTree())
            """,
            file: file,
            line: line
        )
    }

    func assertTypeResolves<T>(
        _ type: T.Type,
        name: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNotNil(
            resolve(type, name: name),
            """
            The container did not resolve the type: \(type). Check that this type is registered correctly.
            Dependency Graph:
            \(_dependencyTree())
            """,
            file: file,
            line: line
        )
    }

    @MainActor
    func assertCollectionResolves<T>(
        _ type: T.Type,
        count expectedCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actualCount = resolveCollection(type).entries.count
        XCTAssert(
            actualCount >= expectedCount,
            """
            The resolved ServiceCollection<\(type)> did not contain the expected number of services \
            (resolved \(actualCount), expected \(expectedCount)).
            Make sure your assembler contains a ServiceCollector behavior.
            """,
            file: file,
            line: line
        )
    }

}

// MARK: - Knit Resolver

public extension Knit.Resolver {

    func assertTypeResolved<T>(
        _ result: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        unsafeResolver.assertTypeResolved(result, file: file, line: line)
    }

    func assertTypeResolves<T>(
        _ type: T.Type,
        name: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        unsafeResolver.assertTypeResolves(type, name: name, file: file, line: line)
    }

    @MainActor
    func assertCollectionResolves<T>(
        _ type: T.Type,
        count expectedCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        unsafeResolver.assertCollectionResolves(type, count: expectedCount, file: file, line: line)
    }

}
