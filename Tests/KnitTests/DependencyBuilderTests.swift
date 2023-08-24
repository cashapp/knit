//
// Copyright © Square, Inc. All rights reserved.
//

@testable import Knit
import XCTest

final class DependencyBuilderTests: XCTestCase {

    func test_assembly3() throws {
        let builder = try DependencyBuilder(modules: [Assembly3(), Assembly1()])
        XCTAssertEqual(builder.assemblies.count, 3)

        XCTAssertTrue(builder.assemblies[0] is Assembly2)
        XCTAssertTrue(builder.assemblies[1] is Assembly1)
        XCTAssertTrue(builder.assemblies[2] is Assembly3)
    }

    func test_assembly3OrderChange() throws {
        let builder = try DependencyBuilder(modules: [Assembly1(), Assembly3()])
        XCTAssertEqual(builder.assemblies.count, 3)

        XCTAssertTrue(builder.assemblies[0] is Assembly2)
        XCTAssertTrue(builder.assemblies[1] is Assembly1)
        XCTAssertTrue(builder.assemblies[2] is Assembly3)
    }

    func test_assembly1() throws {
        let builder = try DependencyBuilder(modules: [Assembly1()])
        XCTAssertEqual(builder.assemblies.count, 2)

        XCTAssertTrue(builder.assemblies[0] is Assembly2)
        XCTAssertTrue(builder.assemblies[1] is Assembly1)
    }

    func test_diamondShape() throws {
        let builder = try DependencyBuilder(modules: [Assembly4(), Assembly1()])
        XCTAssertEqual(builder.assemblies.count, 3)

        XCTAssertTrue(builder.assemblies[0] is Assembly1)
        XCTAssertTrue(builder.assemblies[1] is Assembly2)
        XCTAssertTrue(builder.assemblies[2] is Assembly4)
    }

    func test_parentRegistered() throws {
        let builder = try DependencyBuilder(modules: [Assembly1()]) { type in
            return type == Assembly2.self
        }
        // Assembly2 is not registered because the builder was told that it had been done by the parent
        XCTAssertEqual(builder.assemblies.count, 1)
        XCTAssertTrue(builder.assemblies[0] is Assembly1)
    }

    func test_missingAssembly() {
        XCTAssertThrowsError(try DependencyBuilder(modules: [Assembly3()])) { error in
            XCTAssertEqual(
                error.localizedDescription,
                """
                Found module dependency: Assembly1 that was not provided to assembler.
                Dependency path: Assembly3 -> Assembly1
                Adding a dependency on the testing module for Assembly1 should fix this issue
                """
            )
        }
    }

    func test_invalidOverride() {
        XCTAssertThrowsError(try DependencyBuilder(modules: [Assembly7()])) { error in
            XCTAssertEqual(
                error.localizedDescription,
                """
                Assembly6 used as default override does not implement Assembly5
                SUGGESTED FIX:
                public static var implements: [any ModuleAssembly.Type] {
                    return [Assembly5.self]
                }
                """
            )
        }
    }

}

// Assembly1 depends on Assembly2
private struct Assembly1: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] {
        return [
            Assembly2.self
        ]
    }

    func assemble(container: Container) {}
}

// Assembly2 has no dependencies
private struct Assembly2: AutoInitModuleAssembly {

    static var dependencies: [any ModuleAssembly.Type] {
        return []
    }

    func assemble(container: Container) {}
}

// Assembly3 depends on Assembly1
private struct Assembly3: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] {
        return [Assembly1.self]
    }

    func assemble(container: Container) {}
}

// Assembly4 depends on Assembly1 and Assembly2
// This creates a diamond where both 1 and 4 depend on 2
private struct Assembly4: ModuleAssembly {
    static let dependencies: [any ModuleAssembly.Type] =
        [ Assembly2.self, Assembly1.self ]

    func assemble(container: Container) {}
}

private struct Assembly5: ModuleAssembly, DefaultModuleAssemblyOverride {
    func assemble(container: Container) {}
    static var dependencies: [any ModuleAssembly.Type] { [] }

    // This is not valid because Assembly6 does not implement Assembly5
    typealias OverrideType = Assembly6
}

private struct Assembly6: AutoInitModuleAssembly {
    func assemble(container: Container) {}
    static var dependencies: [any ModuleAssembly.Type] { [] }
}

private struct Assembly7: ModuleAssembly {
    func assemble(container: Container) {}
    static var dependencies: [any ModuleAssembly.Type] { [Assembly5.self] }
}
