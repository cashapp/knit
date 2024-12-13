//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
@testable import Knit
@testable import Swinject
import XCTest

final class ScopedModuleAssemblerTests: XCTestCase {

    @MainActor
    func testScoping() throws {
        // Allows modules at the same level to be registered
        let assembler = try ScopedModuleAssembler<TestResolver>(_modules: [Assembly1()])
        XCTAssertEqual(assembler.internalAssembler.registeredModules.count, 1)
    }

    @MainActor
    func testParentExcluded() throws {
        let parent = try ScopedModuleAssembler<TestResolver>(_modules: [Assembly1()])
        let assembler = try ScopedModuleAssembler<OutsideResolver>(
            parent: parent.internalAssembler,
            _modules: [Assembly3()]
        )
        XCTAssertEqual(assembler.internalAssembler.registeredModules.count, 1)
    }

    @MainActor
    func testPostAssemble() throws {
        let assembler = try ScopedModuleAssembler<TestResolver>(_modules: [Assembly1()]) { container in
            container.register(String.self) { _ in "string" }
        }
        XCTAssertEqual(assembler.resolver.resolve(String.self), "string")
    }

    @MainActor
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

    @MainActor
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

    @MainActor
    func test_integration_initializerBehaviorsPassedToInternalContainer() throws {
        // This is a bit of an integration test to ensure that behaviors passed to the ScopedModuleAssembler initializer
        // are passed through correctly to the backing Container instance.

        let testBehavior = TestBehavior()
        let scopedModuleAssembler = ScopedModuleAssembler<TestResolver>(
            [],
            behaviors: [testBehavior]
        )
        let container = scopedModuleAssembler._container
        // ModuleAssembler automatically adds behaviors for ServiceCollector and AbstractRegistrationContainer
        // so first filter those out
        let foundBehaviors = container.behaviors.filter { behavior in
            let behaviorType = type(of: behavior)
            return behaviorType != ServiceCollector.self &&
                behaviorType != Container.AbstractRegistrationContainer.self
        }
        // There should only be one behavior left
        XCTAssertEqual(foundBehaviors.count, 1)
        let containerBehavior = try XCTUnwrap(foundBehaviors.first as? AnyObject)
        XCTAssert(containerBehavior === testBehavior)
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

private final class TestBehavior: Behavior {

    func container<Type, Service>(
        _ container: Container,
        didRegisterType type: Type.Type,
        toService entry: Swinject.ServiceEntry<Service>,
        withName name: String?
    ) {
        // No op
    }

}
