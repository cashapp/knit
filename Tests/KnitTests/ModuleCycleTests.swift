//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import XCTest

final class ModuleCycleTests: XCTestCase {

    func test_cycleResolution() {
        let assembler = ModuleAssembler([Assembly1()])
        XCTAssertTrue(assembler.isRegistered(Assembly1.self))
        XCTAssertTrue(assembler.isRegistered(Assembly2.self))
        XCTAssertTrue(assembler.isRegistered(Assembly3.self))
        XCTAssertTrue(assembler.isRegistered(Assembly4.self))

        XCTAssertEqual(
            assembler.builder.sourcePath(moduleType: Assembly1.self),
            ["\(Assembly1.self)"]
        )

        XCTAssertEqual(
            assembler.builder.sourcePath(moduleType: Assembly3.self),
            ["\(Assembly1.self)", "\(Assembly3.self)"]
        )
    }

    func test_sourceCycle() {
        let assembler = ModuleAssembler([Assembly5()])
        XCTAssertEqual(
            assembler.builder.sourcePath(moduleType: Assembly5.self),
            ["\(Assembly5.self)"]
        )

        XCTAssertEqual(
            assembler.builder.sourcePath(moduleType: Assembly7.self),
            ["\(Assembly5.self)", "\(Assembly6.self)", "\(Assembly7.self)"]
        )
    }

}

// Assembly1 depends on Assembly2
private struct Assembly1: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [Assembly2.self] }

    func assemble(container: Container) {}
}

// Assembly2 is overriden by default by Assembly3 and requires Assembly4
private struct Assembly2: ModuleAssembly, DefaultModuleAssemblyOverride {
    static var dependencies: [any ModuleAssembly.Type] { [Assembly4.self] }
    func assemble(container: Container) {}
    typealias OverrideType = Assembly3
}

// Assembly3 depends on Assembly2
private struct Assembly3: AutoInitModuleAssembly {
    init() {}
    static var dependencies: [any ModuleAssembly.Type] { [Assembly2.self, Assembly4.self] }
    func assemble(container: Container) {}
    static var implements: [any ModuleAssembly.Type] { [Assembly2.self] }
}

private struct Assembly4: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) {}
}

// Assembly 5-6-7 form a dependency circle

private struct Assembly5: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [Assembly6.self] }
    func assemble(container: Container) {}
}

private struct Assembly6: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [Assembly7.self] }
    func assemble(container: Container) {}
}

private struct Assembly7: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [Assembly5.self] }
    func assemble(container: Container) {}
}