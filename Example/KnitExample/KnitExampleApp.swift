//
// Copyright © Block, Inc. All rights reserved.
//

import SwiftUI
import Knit

@main
struct KnitExampleApp: App {

    let resolver: Resolver

    @MainActor
    init() {
        resolver = ModuleAssembler([KnitExampleAssembly()]).resolver
    }

    var body: some Scene {
        WindowGroup {
            ContentView(resolver: resolver)
        }
    }
}
