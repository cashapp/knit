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
    func assemble(container: Container<RealAssembly.TargetResolver>) {}
}

private final class FakeTestAssembly: FakeAssembly {
    typealias ReplacedAssembly = RealAssembly
    func assemble(container: Container<FakeTestAssembly.TargetResolver>) {}
}

extension RealAssembly: DefaultModuleAssemblyOverride {
    typealias OverrideType = FakeTestAssembly
}
