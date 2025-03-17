//
// Copyright © Block, Inc. All rights reserved.
//

import SwiftUI
import Knit

@main
struct KnitExampleApp: App {

    let assembler: ScopedModuleAssembler<Resolver>
    var resolver: Resolver { assembler.resolver }

    @MainActor
    init() {
        assembler = ScopedModuleAssembler<Resolver>(
            [KnitExampleAssembly()]
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(resolver: resolver)
        }
    }
}
