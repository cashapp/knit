//
// Copyright © Square, Inc. All rights reserved.
//

@testable import KnitLib
import Swinject

protocol TestResolver: Resolver { }

extension Container: TestResolver {}

extension ModuleAssembly {

    // Default to TestResolver to prevent needing to always define this
    typealias TargetResolver = TestResolver

}
