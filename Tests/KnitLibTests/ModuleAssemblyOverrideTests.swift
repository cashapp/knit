//
// Copyright © Square, Inc. All rights reserved.
//

@testable import KnitLib
import XCTest

final class ModuleAssemblyOverrideTests: XCTestCase {

    func test_registrationWithoutFakes() throws {
        let builder = try DependencyBuilder(modules: [Assembly2()], defaultOverrides: .off)
        XCTAssertEqual(builder.assemblies.count, 2)
        XCTAssertTrue(builder.assemblies[0] is Assembly1)
        XCTAssertTrue(builder.assemblies[1] is Assembly2)
    }

    func test_registrationWithFakes() throws {
        let builder = try DependencyBuilder(modules: [Assembly2(), Assembly2Fake()], defaultOverrides: .off)
        XCTAssertEqual(builder.assemblies.count, 3)
        XCTAssertTrue(builder.assemblies[0] is Assembly1)
        XCTAssertTrue(builder.assemblies[1] is FakeAssembly3)
        XCTAssertTrue(builder.assemblies[2] is Assembly2Fake)
    }

    func test_serviceRegisteredWithoutFakes() {
        let resolver = ModuleAssembler([Assembly2()]).resolver
        XCTAssertTrue(resolver.resolve(Service2Protocol.self) is Service2)
    }

    func test_servicesRegisteredWithFakes() {
        let resolver = ModuleAssembler([Assembly2(), Assembly2Fake()]).resolver
        XCTAssertTrue(resolver.resolve(Service2Protocol.self) is Service2Fake)
    }

    func test_assemblerWithDefaultOverrides() {
        let assembler = ModuleAssembler([Assembly2()], defaultOverrides: .on)
        XCTAssertTrue(assembler.registeredModules.contains(where: {$0 == Assembly1Fake.self}))
        XCTAssertTrue(assembler.isRegistered(Assembly1Fake.self))
        // Treat Assembly1 as being registered because the mock is
        XCTAssertTrue(assembler.isRegistered(Assembly1.self))
    }

    func test_noDefaultOverrideForInputModules() {
        let assembler = ModuleAssembler([Assembly1()], defaultOverrides: .on)
        XCTAssertTrue(assembler.isRegistered(Assembly1.self))
        // The fake is not automatically registered
        XCTAssertFalse(assembler.isRegistered(Assembly1Fake.self))
    }

    func test_explicitInputOverride() {
        let assembler = ModuleAssembler([Assembly1(), Assembly1Fake()], defaultOverrides: .on)
        XCTAssertTrue(assembler.isRegistered(Assembly1.self))
        XCTAssertTrue(assembler.isRegistered(Assembly1Fake.self))
    }

    func test_assemblerWithoutDefaultOverrides() {
        let assembler = ModuleAssembler([Assembly2()], defaultOverrides: .off)
        XCTAssertTrue(assembler.isRegistered(Assembly1.self))
        XCTAssertFalse(assembler.isRegistered(Assembly1Fake.self))
    }

    func test_assemblerWithFakes() {
        let assembler = ModuleAssembler([Assembly2Fake()])
        XCTAssertFalse(assembler.registeredModules.contains(where: {$0 == Assembly2.self}))
        XCTAssertTrue(assembler.isRegistered(Assembly2.self))
        XCTAssertTrue(assembler.isRegistered(Assembly2Fake.self))
    }

    func test_parentFakes() {
        let parent = ModuleAssembler([Assembly1Fake()])
        let child = ModuleAssembler(parent: parent, [Assembly2()])
        XCTAssertTrue(child.isRegistered(Assembly1.self))
        XCTAssertTrue(child.isRegistered(Assembly1Fake.self))
    }

    func test_autoFake() {
        let assembler = ModuleAssembler([Assembly5()])
        XCTAssertTrue(assembler.isRegistered(Assembly4.self))
        XCTAssertTrue(assembler.isRegistered(Assembly4Fake.self))
        XCTAssertTrue(assembler.isRegistered(Assembly5.self))
    }

    func test_overrideDefaultOverride() {
        let assembler = ModuleAssembler(
            [Assembly4(), Assembly4Fake2()],
            defaultOverrides: .on
        )
        XCTAssertTrue(assembler.isRegistered(Assembly4.self))
        XCTAssertTrue(assembler.isRegistered(Assembly4Fake2.self))
        XCTAssertFalse(assembler.isRegistered(Assembly4Fake.self))
    }

    func test_nonAutoOverride() throws {
        let builder = try DependencyBuilder(modules: [Assembly1(), NonAutoOverride()], defaultOverrides: .off)
        XCTAssertTrue(builder.assemblies.first is NonAutoOverride)
    }

    func test_parentNonAutoOverride() {
        let parent = ModuleAssembler([NonAutoOverride()])
        let child = ModuleAssembler(parent: parent, [Assembly1()], defaultOverrides: .off)
        XCTAssertTrue(child.isRegistered(Assembly1.self))
        XCTAssertTrue(child.registeredModules.isEmpty)
    }

    func test_multipleOverrides() {
        let assembler = ModuleAssembler(
            [MultipleDependencyAssembly(), MultipleOverrideAssembly()],
            defaultOverrides: .off
        )

        XCTAssertTrue(assembler.isRegistered(Assembly1.self))
        XCTAssertTrue(assembler.isRegistered(Assembly5.self))
        XCTAssertTrue(assembler.isRegistered(MultipleDependencyAssembly.self))
        XCTAssertTrue(assembler.isRegistered(MultipleOverrideAssembly.self))
    }

}

// Assembly with no dependencies
private struct Assembly1: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] {
        return []
    }
    func assemble(container: Container) {}
}

// Depends on Assembly1 and registers Service2Protocol
private struct Assembly2: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] {
        return [Assembly1.self]
    }

    func assemble(container: Container) {
        container.autoregister(Service2Protocol.self, initializer: Service2.init)
    }
}

// Mock implementaiton of Assembly2. Adds an extra dependency on Assembly3
private struct Assembly2Fake: AutoInitModuleAssembly {

    func assemble(container: Container) {
        Assembly2().assemble(container: container)
        container.autoregister(Service2Protocol.self, initializer: Service2Fake.init)
    }

    static var implements: [any ModuleAssembly.Type] { [Assembly2.self] }
    static var dependencies: [any ModuleAssembly.Type] {
        return [FakeAssembly3.self]
    }
}

private struct Assembly1Fake: AutoInitModuleAssembly {
    func assemble(container: Container) {}
    static var dependencies: [any ModuleAssembly.Type] { [] }
    static var implements: [any ModuleAssembly.Type] { [Assembly1.self] }
}

extension Assembly1: DefaultModuleAssemblyOverride {
    typealias OverrideType = Assembly1Fake
}

private struct FakeAssembly3: AutoInitModuleAssembly {
    func assemble(container: Container) { }
    static var dependencies: [any ModuleAssembly.Type] { [] }
}

// An Assembly that is *not* AutoInit
private struct Assembly4: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) { }
}

extension Assembly4: DefaultModuleAssemblyOverride {
    typealias OverrideType = Assembly4Fake
}

// The fake is AutoInit so can be created even when Assembly4 is unavailable
private struct Assembly4Fake: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) { }
    static var implements: [any ModuleAssembly.Type] { [Assembly4.self] }
}

private struct Assembly4Fake2: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) { }
    static var implements: [any ModuleAssembly.Type] { [Assembly4.self] }
}

private struct NonAutoOverride: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) { }
    static var implements: [any ModuleAssembly.Type] { [Assembly1.self] }
}

private struct Assembly5: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [Assembly4.self] }
    func assemble(container: Container) { }
}

private struct MultipleDependencyAssembly: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [Assembly1.self, Assembly5.self] }
    func assemble(container: Container) { }
}

private struct MultipleOverrideAssembly: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) { }
    static var implements: [any ModuleAssembly.Type] { [Assembly1.self, Assembly4.self, Assembly5.self] }
}

private protocol Service2Protocol {}
private struct Service2: Service2Protocol {}
private struct Service2Fake: Service2Protocol {}
