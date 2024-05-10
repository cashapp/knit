//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
@testable import Knit
import XCTest

final class ScopedModuleAssemblerTests: XCTestCase {

    func testScoping() throws {
        // Allows modules at the same level to be registered
        let assembler = try ScopedModuleAssembler<TestResolver>(_modules: [Assembly1()])
        XCTAssertEqual(assembler.internalAssembler.registeredModules.count, 1)
    }

    func testParentExcluded() throws {
        let parent = try ScopedModuleAssembler<TestResolver>(_modules: [Assembly1()])
        let assembler = try ScopedModuleAssembler<OutsideResolver>(
            parent: parent.internalAssembler,
            _modules: [Assembly3()]
        )
        XCTAssertEqual(assembler.internalAssembler.registeredModules.count, 1)
    }

    func testPostAssemble() throws {
        let assembler = try ScopedModuleAssembler<TestResolver>(_modules: [Assembly1()]) { container in
            container.register(String.self) { _ in "string" }
        }
        XCTAssertEqual(assembler.resolver.resolve(String.self), "string")
    }

    func testOutOfScopeAssemblyThrows() {
        XCTAssertThrowsError(
            try ScopedModuleAssembler<TestResolver>(
                _modules: [ Assembly2() ]
            ),
            "Assembly2 with target OutsideResolver should throw an error",
            { error in
                XCTAssertEqual(
                    error.localizedDescription,
                    """
                    Assembly2 did not pass assembly validation check: The ModuleAssembly's TargetResolver is incorrect.
                    Expected: TestResolver
                    Actual: OutsideResolver
                    """
                )
            }
        )
    }

    func testIncorrectInputScope() throws {
        let parent = try ScopedModuleAssembler<TestResolver>(_modules: [Assembly1()])
        // Even though Assembly1 is already registered, because it was explicitly provided the validation should fail
        XCTAssertThrowsError(
            try ScopedModuleAssembler<OutsideResolver>(
                parent: parent.internalAssembler,
                _modules: [Assembly3(), Assembly1()]
            ),
            "Assembly1 with target TestResolver should throw an error",
            { error in
                XCTAssertEqual(
                    error.localizedDescription,
                    """
                    Assembly1 did not pass assembly validation check: The ModuleAssembly's TargetResolver is incorrect.
                    Expected: OutsideResolver
                    Actual: TestResolver
                    """
                )
            }
        )
    }

}

private struct Assembly1: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) { }
}

protocol OutsideResolver: Resolver { }

private struct Assembly2: AutoInitModuleAssembly {
    typealias TargetResolver = OutsideResolver
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) { }
}

private struct Assembly3: AutoInitModuleAssembly {
    typealias TargetResolver = OutsideResolver
    static var dependencies: [any ModuleAssembly.Type] { [Assembly1.self] }
    func assemble(container: Container) { }
}
