//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import Swinject

protocol TestResolver: Resolver { }

extension Container: TestResolver {}

extension ModuleAssembly {

    // Default to TestResolver to prevent needing to always define this
    typealias TargetResolver = TestResolver

}
