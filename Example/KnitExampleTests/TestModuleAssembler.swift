//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import Knit
@testable import KnitExample

extension KnitExampleAssembly {
    @MainActor
    static func makeAssemblerForTests() -> ModuleAssembler {
        ModuleAssembler(
            [KnitExampleAssembly()]
        )
    }

    static func makeArgumentsForTests() -> KnitExampleRegistrationTestArguments {
        return .init(
            exampleArgumentServiceArg: "Test",
            exampleArgumentServiceArgument: .init(string: "Test"),
            closureServiceClosure: {},
            closureServiceArg1: {}
        )
    }

}

extension KnitExampleUserAssembly {
    @MainActor
    static func makeAssemblerForTests() -> ModuleAssembler {
        ModuleAssembler(
            [KnitExampleUserAssembly(), KnitExampleAssembly()]
        )
    }
}
