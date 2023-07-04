// Copyright © Square, Inc. All rights reserved.

import Foundation
import Knit
@testable import KnitExample

func makeAssemblerForTests() -> Assembler {
    Assembler([KnitExampleAssembly()])
}

func makeArgumentsForTests() -> KnitRegistrationTestArguments {
    return .init(
        exampleArgumentServiceArg: "Test",
        exampleArgumentServiceArgument: .init(string: "Test"),
        closureServiceClosure: {},
        closureServiceArg1: {}
    )
}
