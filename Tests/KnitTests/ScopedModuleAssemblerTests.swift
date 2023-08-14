//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
@testable import Knit
import XCTest

final class ScopedModuleAssemblerTests: XCTestCase {

    func testScoping() {
        // Allows modules at the same level to be registered
        let assembler = ScopedModuleAssembler<TestResolver>([Assembly1()])
        XCTAssertEqual(assembler.internalAssembler.registeredModules.count, 1)
    }

    func testPostAssemble() {
        let assembler = ScopedModuleAssembler<TestResolver>([Assembly1()]) { container in
            container.register(String.self) { _ in "string" }
        }
        XCTAssertEqual(assembler.resolver.resolve(String.self), "string")
    }

}

private struct Assembly1: ModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) { }
}
