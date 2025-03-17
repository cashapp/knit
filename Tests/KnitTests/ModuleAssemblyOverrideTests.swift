//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import XCTest

final class ModuleAssemblyOverrideTests: XCTestCase {

    func test_registrationWithoutFakes() throws {
        let builder = try DependencyBuilder(modules: [Assembly2()], overrideBehavior: .disableDefaultOverrides)
        XCTAssertEqual(builder.assemblies.count, 2)
        XCTAssertTrue(builder.assemblies[0] is Assembly1)
        XCTAssertTrue(builder.assemblies[1] is Assembly2)
    }

    func test_registrationWithFakes() throws {
        let builder = try DependencyBuilder(
            modules: [Assembly2(), Assembly2Fake()],
            overrideBehavior: .disableDefaultOverrides
        )
        XCTAssertEqual(builder.assemblies.count, 3)
        XCTAssertTrue(builder.assemblies[0] is Assembly1)
        XCTAssertTrue(builder.assemblies[1] is FakeAssembly3)
        XCTAssertTrue(builder.assemblies[2] is Assembly2Fake)

        XCTAssertEqual(
            builder.dependencyTree.debugDescription,
            """
            Assembly2 (Assembly2Fake)
              - Assembly1
            Assembly2Fake
              - FakeAssembly3
            """
        )
    }

    @MainActor
    func test_serviceRegisteredWithoutFakes() throws {
        let resolver = try ModuleAssembler.testing([Assembly2()]).resolver
        XCTAssertTrue(resolver.resolve(Service2Protocol.self) is Service2)
    }

    @MainActor
    func test_servicesRegisteredWithFakes() throws {
        let resolver = try ModuleAssembler.testing([Assembly2(), Assembly2Fake()]).resolver
        XCTAssertTrue(resolver.resolve(Service2Protocol.self) is Service2Fake)
    }

    @MainActor
    func test_assemblerWithDefaultOverrides() throws {
        let assembler = try ModuleAssembler(
            _modules: [Assembly2()],
            overrideBehavior: .useDefaultOverrides,
            preAssemble: {
                Container<TestResolver>._instantiateAndRegister(_swinjectContainer: $0)
            }
        )
        XCTAssertTrue(assembler.registeredModules.contains(where: {$0 == Assembly1Fake.self}))
        XCTAssertTrue(assembler.isRegistered(Assembly1Fake.self))
        // Treat Assembly1 as being registered because the mock is
        XCTAssertTrue(assembler.isRegistered(Assembly1.self))
    }

    @MainActor
    func test_noDefaultOverrideForInputModules() throws {
        let assembler = try ModuleAssembler(
            _modules: [Assembly1()],
            overrideBehavior: .useDefaultOverrides,
            preAssemble: {
                Container<TestResolver>._instantiateAndRegister(_swinjectContainer: $0)
            }
        )
        XCTAssertTrue(assembler.isRegistered(Assembly1.self))
        // The fake is not automatically registered
        XCTAssertFalse(assembler.isRegistered(Assembly1Fake.self))
    }

    @MainActor
    func test_explicitInputOverride() throws {
        let assembler = try ModuleAssembler(
            _modules: [Assembly1(), Assembly1Fake()],
            overrideBehavior: .useDefaultOverrides,
            preAssemble: {
                Container<TestResolver>._instantiateAndRegister(_swinjectContainer: $0)
            }
        )
        XCTAssertTrue(assembler.isRegistered(Assembly1.self))
        XCTAssertTrue(assembler.isRegistered(Assembly1Fake.self))
    }

    @MainActor
    func test_assemblerWithoutDefaultOverrides() throws {
        let assembler = try ModuleAssembler(
            _modules: [Assembly2()],
            overrideBehavior: .disableDefaultOverrides,
            preAssemble: {
                Container<TestResolver>._instantiateAndRegister(_swinjectContainer: $0)
            }
        )
        XCTAssertTrue(assembler.isRegistered(Assembly1.self))
        XCTAssertFalse(assembler.isRegistered(Assembly1Fake.self))
    }

    @MainActor
    func test_assemblerWithFakes() throws {
        let assembler = try ModuleAssembler(
            _modules: [Assembly2Fake()],
            preAssemble: {
                Container<TestResolver>._instantiateAndRegister(_swinjectContainer: $0)
            }
        )
        XCTAssertFalse(assembler.registeredModules.contains(where: {$0 == Assembly2.self}))
        XCTAssertTrue(assembler.isRegistered(Assembly2.self))
        XCTAssertTrue(assembler.isRegistered(Assembly2Fake.self))
    }

    @MainActor
    func test_parentFakes() throws {
        let parent = try ModuleAssembler.testing([Assembly1Fake()])
        let child = ModuleAssembler(parent: parent, [Assembly2()])
        XCTAssertTrue(child.isRegistered(Assembly1.self))
        XCTAssertTrue(child.isRegistered(Assembly1Fake.self))
    }

    @MainActor
    func test_autoFake() throws {
        let assembler = try ModuleAssembler(
            _modules: [Assembly5()],
            preAssemble: {
                Container<TestResolver>._instantiateAndRegister(_swinjectContainer: $0)
            }
        )
        XCTAssertTrue(assembler.isRegistered(Assembly4.self))
        XCTAssertTrue(assembler.isRegistered(Assembly4Fake.self))
        XCTAssertTrue(assembler.isRegistered(Assembly5.self))
    }

    @MainActor
    func test_overrideDefaultOverride() throws {
        let assembler = try ModuleAssembler.testing(
            [Assembly4(), Assembly4Fake2()],
            overrideBehavior: .useDefaultOverrides
        )
        XCTAssertTrue(assembler.isRegistered(Assembly4.self))
        XCTAssertTrue(assembler.isRegistered(Assembly4Fake2.self))
        XCTAssertFalse(assembler.isRegistered(Assembly4Fake.self))
    }

    func test_nonAutoOverride() throws {
        let builder = try DependencyBuilder(
            modules: [Assembly1(), NonAutoOverride()],
            overrideBehavior: .disableDefaultOverrides
        )
        XCTAssertTrue(builder.assemblies.first is NonAutoOverride)
    }

    @MainActor
    func test_parentNonAutoOverride() throws {
        let parent = try ModuleAssembler.testing([NonAutoOverride()])
        let child = ModuleAssembler(parent: parent, [Assembly1()], overrideBehavior: .disableDefaultOverrides)
        XCTAssertTrue(child.isRegistered(Assembly1.self))
        XCTAssertTrue(child.registeredModules.isEmpty)

        XCTAssertEqual(
            child.resolver._dependencyTree().debugDescription,
            """
            Assembly1
            """
        )
    }

    @MainActor
    func test_multipleOverrides() throws {
        let assembler = try ModuleAssembler(
            _modules: [MultipleDependencyAssembly(), MultipleOverrideAssembly()],
            overrideBehavior: .disableDefaultOverrides,
            preAssemble: {
                Container<TestResolver>._instantiateAndRegister(_swinjectContainer: $0)
            }
        )

        XCTAssertTrue(assembler.isRegistered(Assembly1.self))
        XCTAssertTrue(assembler.isRegistered(Assembly5.self))
        XCTAssertTrue(assembler.isRegistered(MultipleDependencyAssembly.self))
        XCTAssertTrue(assembler.isRegistered(MultipleOverrideAssembly.self))

        XCTAssertEqual(
            assembler.resolver._dependencyTree().debugDescription,
            """
            MultipleDependencyAssembly
              - Assembly1 (MultipleOverrideAssembly)
              - Assembly5 (MultipleOverrideAssembly)
                - Assembly4 (MultipleOverrideAssembly)
            MultipleOverrideAssembly
            """
        )
    }

}

// Assembly with no dependencies
private struct Assembly1: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] {
        return []
    }
    func assemble(container: Container<Self.TargetResolver>) {}
}

// Depends on Assembly1 and registers Service2Protocol
private struct Assembly2: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] {
        return [Assembly1.self]
    }

    func assemble(container: Container<Self.TargetResolver>) {
        container.register(Service2Protocol.self, factory: { _ in Service2() })
    }
}

// Mock implementation of Assembly2. Adds an extra dependency on Assembly3
private struct Assembly2Fake: AutoInitModuleAssembly {

    func assemble(container: Container<Self.TargetResolver>) {
        Assembly2().assemble(container: container)
        container.register(Service2Protocol.self, factory: { _ in Service2Fake() })
    }

    static var replaces: [any ModuleAssembly.Type] { [Assembly2.self] }
    static var dependencies: [any ModuleAssembly.Type] {
        return [FakeAssembly3.self]
    }
}

private struct Assembly1Fake: AutoInitModuleAssembly {
    func assemble(container: Container<Self.TargetResolver>) {}
    static var dependencies: [any ModuleAssembly.Type] { [] }
    static var replaces: [any ModuleAssembly.Type] { [Assembly1.self] }
}

extension Assembly1: DefaultModuleAssemblyOverride {
    typealias OverrideType = Assembly1Fake
}

private struct FakeAssembly3: AutoInitModuleAssembly {
    func assemble(container: Container<Self.TargetResolver>) { }
    static var dependencies: [any ModuleAssembly.Type] { [] }
}

// An Assembly that is *not* AutoInit
private struct Assembly4: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container<Self.TargetResolver>) { }
}

extension Assembly4: DefaultModuleAssemblyOverride {
    typealias OverrideType = Assembly4Fake
}

// The fake is AutoInit so can be created even when Assembly4 is unavailable
private struct Assembly4Fake: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container<Self.TargetResolver>) { }
    static var replaces: [any ModuleAssembly.Type] { [Assembly4.self] }
}

private struct Assembly4Fake2: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container<Self.TargetResolver>) { }
    static var replaces: [any ModuleAssembly.Type] { [Assembly4.self] }
}

private struct NonAutoOverride: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container<Self.TargetResolver>) { }
    static var replaces: [any ModuleAssembly.Type] { [Assembly1.self] }
}

private struct Assembly5: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [Assembly4.self] }
    func assemble(container: Container<Self.TargetResolver>) { }
}

private struct MultipleDependencyAssembly: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [Assembly1.self, Assembly5.self] }
    func assemble(container: Container<Self.TargetResolver>) { }
}

private struct MultipleOverrideAssembly: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container<Self.TargetResolver>) { }
    static var replaces: [any ModuleAssembly.Type] { [Assembly1.self, Assembly4.self, Assembly5.self] }
}

private protocol Service2Protocol {}
private struct Service2: Service2Protocol {}
private struct Service2Fake: Service2Protocol {}
