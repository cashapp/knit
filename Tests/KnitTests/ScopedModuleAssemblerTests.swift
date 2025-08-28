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
        XCTAssertEqual(assembler.internalAssembler.registeredReferences.count, 1)
    }

    @MainActor
    func testParentExcluded() throws {
        let parent = try ScopedModuleAssembler<TestResolver>(_modules: [Assembly1()])
        let assembler = try ScopedModuleAssembler<OutsideResolver>(
            parent: parent.internalAssembler,
            _modules: [Assembly3()]
        )
        XCTAssertEqual(assembler.internalAssembler.registeredReferences.count, 1)
    }

    @MainActor
    func testPostAssemble() throws {
        let assembler = try ScopedModuleAssembler<TestResolver>(_modules: [Assembly1()]) { container in
            container.register(String.self) { _ in "string" }
        }
        XCTAssertEqual(assembler.unsafeResolver.resolve(String.self), "string")
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
        let container = scopedModuleAssembler.internalAssembler._swinjectContainer
        // ModuleAssembler automatically adds behaviors for ServiceCollector and AbstractRegistrationContainer
        // so first filter those out
        let foundBehaviors = container.behaviors.filter { behavior in
            let behaviorType = type(of: behavior)
            return behaviorType != ServiceCollector.self &&
                behaviorType != SwinjectContainer.AbstractRegistrationContainer.self
        }
        // There should only be one behavior left
        XCTAssertEqual(foundBehaviors.count, 1)
        let containerBehavior = try XCTUnwrap(foundBehaviors.first as? AnyObject)
        XCTAssert(containerBehavior === testBehavior)
    }

}

private struct Assembly1: AutoInitModuleAssembly {
    typealias TargetResolver = TestResolver
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Knit.Container<Self.TargetResolver>) { }
}

protocol OutsideResolver: SwinjectResolver { }

private struct Assembly2: AutoInitModuleAssembly {
    typealias TargetResolver = OutsideResolver
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Knit.Container<Self.TargetResolver>) { }
}

private struct Assembly3: AutoInitModuleAssembly {
    typealias TargetResolver = OutsideResolver
    static var dependencies: [any ModuleAssembly.Type] { [Assembly1.self] }
    func assemble(container: Knit.Container<Self.TargetResolver>) { }
}

private final class TestBehavior: Behavior {

    func container<Type, Service>(
        _ container: SwinjectContainer,
        didRegisterType type: Type.Type,
        toService entry: Swinject.ServiceEntry<Service>,
        withName name: String?
    ) {
        // No op
    }

}
