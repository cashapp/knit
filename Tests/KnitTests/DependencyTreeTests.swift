//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import XCTest

final class DependencyTreeTests: XCTestCase {

    func test_source_paths() {
        var tree = DependencyTree(inputModules: [Assembly1()])
        tree.add(assemblyType: AssemblyReference(Assembly2.self), source: AssemblyReference(Assembly1.self))

        XCTAssertEqual(
            tree.sourcePath(moduleType: Assembly1.self),
            ["Assembly1"]
        )

        XCTAssertEqual(
            tree.sourcePath(moduleType: Assembly2.self),
            ["Assembly1", "Assembly2"]
        )
    }

    func test_tree_structure() {
        var tree = DependencyTree(inputModules: [Assembly1(), Assembly4()])
        tree.add(assemblyType: AssemblyReference(Assembly2.self), source: AssemblyReference(Assembly1.self))
        tree.add(assemblyType: AssemblyReference(Assembly3.self), source: AssemblyReference(Assembly2.self))

        XCTAssertEqual(
            tree.debugDescription,
            """
            Assembly1
              - Assembly2
                - Assembly3
            Assembly4
            """
        )
    }

}

private struct Assembly1: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { return [] }
    func assemble(container: Container<Self.TargetResolver>) {}
}

private struct Assembly2: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { return [] }
    func assemble(container: Container<Self.TargetResolver>) {}
}

private struct Assembly3: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { return [] }
    func assemble(container: Container<Self.TargetResolver>) {}
}

private struct Assembly4: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { return [] }
    func assemble(container: Container<Self.TargetResolver>) {}
}
