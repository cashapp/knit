//
// Copyright © Block, Inc. All rights reserved.
//

import SwiftUI
import Knit

@main
struct KnitExampleApp: App {

    let assembler: ScopedModuleAssembler<BaseResolver>
    var resolver: BaseResolver { assembler.resolver }

    @MainActor
    init() {
        assembler = ScopedModuleAssembler<BaseResolver>(
            [KnitExampleAssembly()]
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(resolver: resolver)
        }
    }
}
