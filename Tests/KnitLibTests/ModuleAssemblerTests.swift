//
// Copyright © Square, Inc. All rights reserved.
//

@testable import KnitLib
import XCTest

final class ModuleAssemblerTests: XCTestCase {

    func test_auto_assembler() {
        let resolver = ModuleAssembler([Assembly1()]).resolver
        XCTAssertNotNil(resolver.resolve(Service1.self))
    }

    func test_non_auto_assembler() {
        let resolver = ModuleAssembler([
            Assembly3(),
            Assembly1(),
        ]).resolver
        XCTAssertNotNil(resolver.resolve(Service1.self))
        XCTAssertNotNil(resolver.resolve(Service3.self))
    }

    func test_registered_modules() {
        let assembler = ModuleAssembler([Assembly1()])
        XCTAssertTrue(assembler.registeredModules.contains(where: {$0 == Assembly1.self}))
        XCTAssertTrue(assembler.registeredModules.contains(where: {$0 == Assembly2.self}))
        XCTAssertFalse(assembler.registeredModules.contains(where: {$0 == Assembly3.self}))
    }

    func test_parent_assembler() {
        // Put some modules in the parent and some in the child.
        let parent = ModuleAssembler([Assembly1()])
        let child = ModuleAssembler(parent: parent, [Assembly3()])
        XCTAssertTrue(child.isRegistered(Assembly1.self))
        XCTAssertTrue(child.isRegistered(Assembly3.self))
        XCTAssertTrue(child.isRegistered(Assembly2.self))

        XCTAssertFalse(child.registeredModules.contains(where: {$0 == Assembly1.self}))

        XCTAssertNotNil(child.resolver.resolve(Service1.self))
        XCTAssertNil(parent.resolver.resolve(Service3.self))
    }
}

// Assembly1 depends on Assembly2 and registers Service1
private struct Assembly1: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] {
        return [
            Assembly2.self
        ]
    }

    func assemble(container: Container) {
        container.autoregister(Service1.self, initializer: Service1.init)
    }
}

// Assembly2 has no dependencies and registers Service2
private struct Assembly2: AutoInitModuleAssembly {

    static var dependencies: [any ModuleAssembly.Type] {
        return []
    }

    func assemble(container: Container) {
        container.autoregister(Service2.self, initializer: Service2.init)
    }
}

// Assembly3 depends on Assembly1 and registers Service3
private struct Assembly3: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] {
        return [Assembly1.self]
    }

    func assemble(container: Container) {
        container.autoregister(Service3.self, initializer: Service3.init)
    }
}

// Service1 depends on Service2
private struct Service1 {

    let service2: Service2

    init(service2: Service2) {
        self.service2 = service2
    }

}

private struct Service2 {}
private struct Service3 {}
