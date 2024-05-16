//
// Copyright © Block, Inc. All rights reserved.
//

import Knit
import XCTest

final class FakeAssemblyTests: XCTestCase {
    func testFakeAssembly() {
        XCTAssertEqual(FakeTestAssembly.dependencies.count, 0)
    }
}

private final class RealAssembly: AutoInitModuleAssembly {
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Swinject.Container) {}
}

private final class FakeTestAssembly: FakeAssembly {
    typealias ImplementedAssembly = RealAssembly
    func assemble(container: Swinject.Container) {}
}

extension RealAssembly: DefaultModuleAssemblyOverride {
    typealias OverrideType = FakeTestAssembly
}
