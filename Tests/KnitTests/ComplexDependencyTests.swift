//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import XCTest

final class ComplexDependencyTests: XCTestCase {

    func testFakeDependency() throws {
        let builder = try DependencyBuilder(modules: [Assembly1()])
        XCTAssertEqual(builder.assemblies.count, 3)

        XCTAssertTrue(builder.assemblies[0] is Assembly2Fake)
        XCTAssertTrue(builder.assemblies[1] is Assembly3)
        XCTAssertTrue(builder.assemblies[2] is Assembly1)

        XCTAssertEqual(
            builder.dependencyTree.sourcePath(moduleType: Assembly2Fake.self),
            ["Assembly1", "Assembly3", "Assembly2Fake"]
        )

        XCTAssertEqual(
            builder.dependencyTree.debugDescription,
            """
            Assembly1
              - Assembly2 (Assembly2Fake)
              - Assembly3
                - Assembly2Fake
            """
        )
    }

    func testCyclicDependency() throws {
        let builder = try DependencyBuilder(modules: [Assembly4()])
        XCTAssertEqual(builder.assemblies.count, 2)
        XCTAssertTrue(builder.assemblies[0] is Assembly5)
        XCTAssertTrue(builder.assemblies[1] is Assembly4)

        XCTAssertEqual(
            builder.dependencyTree.debugDescription,
            """
            Assembly4
              - Assembly5
            """
        )
    }

}

// Assembly1 depends on Assembly2 and Assembly3
private struct Assembly1: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [ Assembly3.self, Assembly2.self ] }
    func assemble(container: Container) {}
}

// Assembly2 has no dependencies
private struct Assembly2: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) {}
}

// Assembly2Fake overrides Assembly2
private struct Assembly2Fake: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    static var replaces: [any ModuleAssembly.Type] { [Assembly2.self] }
    func assemble(container: Container) {}
}

// Assembly3 depends on a fake version of Assembly2
private struct Assembly3: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [Assembly2Fake.self] }
    func assemble(container: Container) {}
}

// Assembly4 has a cycle with Assembly5
private struct Assembly4: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [Assembly5.self] }
    func assemble(container: Container) {}
}

// Assembly5 has a cycle with Assembly4
private struct Assembly5: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [Assembly4.self] }
    func assemble(container: Container) {}
}
