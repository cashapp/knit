//
// Copyright © Block, Inc. All rights reserved.
//

import Knit
import SwiftUI

struct ContentView: View {

    let resolver: Resolver

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text(resolver.exampleService().title)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static let assembler = ScopedModuleAssembler<Resolver>([KnitExampleAssembly()])
    static var previews: some View {
        return ContentView(resolver: assembler.resolver)
    }
}
