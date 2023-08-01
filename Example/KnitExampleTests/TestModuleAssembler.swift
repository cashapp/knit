// Copyright © Square, Inc. All rights reserved.

import Foundation
import Knit
@testable import KnitExample

extension KnitExampleAssembly {
    static func makeAssemblerForTests() -> Assembler {
        Assembler([KnitExampleAssembly()])
    }

    static func makeArgumentsForTests() -> KnitRegistrationTestArguments {
        return .init(
            exampleArgumentServiceArg: "Test",
            exampleArgumentServiceArgument: .init(string: "Test"),
            closureServiceClosure: {},
            closureServiceArg1: {}
        )
    }

}
