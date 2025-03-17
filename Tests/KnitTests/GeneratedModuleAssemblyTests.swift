//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
@testable import Knit
import XCTest

final class GeneratedModuleAssemblyTests: XCTestCase {

    func test_defaultDependencies() throws {
        let builder = try DependencyBuilder(modules: [Assembly1()])

        XCTAssertEqual(builder.assemblies.count, 2)
        XCTAssertTrue(builder.assemblies[0] is Assembly3)
        XCTAssertTrue(builder.assemblies[1] is Assembly1)
    }

    func test_overridenDependencies() throws {
        let builder = try DependencyBuilder(modules: [Assembly2()])

        XCTAssertEqual(builder.assemblies.count, 1)
        XCTAssertTrue(builder.assemblies[0] is Assembly2)
    }

}

private struct Assembly1: AutoInitModuleAssembly {
    func assemble(container: Container<Self.TargetResolver>) { }
}

extension Assembly1: GeneratedModuleAssembly {
    static var generatedDependencies: [any ModuleAssembly.Type] { [Assembly3.self] }
}

private struct Assembly2: AutoInitModuleAssembly {
    func assemble(container: Container<Self.TargetResolver>) { }
    // Assembly2 explicitly sets dependencies so ignores generatedDependencies
    static var dependencies: [any ModuleAssembly.Type] { [] }
}

extension Assembly2: GeneratedModuleAssembly {
    static var generatedDependencies: [any ModuleAssembly.Type] { [Assembly3.self] }
}

private struct Assembly3: AutoInitModuleAssembly {
    func assemble(container: Container<Self.TargetResolver>) { }
    static var dependencies: [any ModuleAssembly.Type] { [] }
}
