// Copyright © Square, Inc. All rights reserved.

import SwiftUI
import Knit

@main
struct KnitExampleApp: App {

    let resolver = ModuleAssembler([KnitExampleAssembly()]).resolver

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
