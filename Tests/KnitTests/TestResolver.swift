//  Created by Alexander skorulis on 15/8/2023.

@testable import Knit
import Swinject

protocol TestResolver: Resolver { }

extension Container: TestResolver {}

extension ModuleAssembly {

    // Default to TestResolver to prevent needing to define for all 
    typealias TargetResolver = TestResolver

}
