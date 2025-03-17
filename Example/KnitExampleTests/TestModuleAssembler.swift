//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
@testable import Knit
@testable import KnitExample

extension KnitExampleAssembly {
    @MainActor
    static func makeAssemblerForTests() -> ModuleAssembler {
        ModuleAssembler(
            [KnitExampleAssembly()],
            preAssemble: { container in
                Knit.Container<Knit.Resolver>._instantiateAndRegister(_swinjectContainer: container)
            }
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
            [KnitExampleUserAssembly(), KnitExampleAssembly()],
            preAssemble: { container in
                Knit.Container<Knit.Resolver>._instantiateAndRegister(_swinjectContainer: container)
            }
        )
    }
}
