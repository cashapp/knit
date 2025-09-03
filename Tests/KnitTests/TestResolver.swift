//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import Swinject

class TestResolver: BaseResolver {}

extension ModuleAssembly {

    // Default to TestResolver to prevent needing to always define this
    typealias TargetResolver = TestResolver

}

extension ModuleAssembler {

    // Convenience throwing init that fills in preAssemble and autoConfigureContainers
    @MainActor convenience init(
        parent: ModuleAssembler? = nil,
        _modules modules: [any ModuleAssembly],
        overrideBehavior: OverrideBehavior = .defaultOverridesWhenTesting,
        assemblyValidation: ((any ModuleAssembly.Type) throws -> Void)? = nil,
        errorFormatter: ModuleAssemblerErrorFormatter = DefaultModuleAssemblerErrorFormatter(),
        behaviors: [Behavior] = [],
        postAssemble: ((SwinjectContainer) -> Void)? = nil
    ) throws {
        try self.init(
            parent: parent,
            _modules: modules,
            overrideBehavior: overrideBehavior,
            assemblyValidation: assemblyValidation,
            errorFormatter: errorFormatter,
            behaviors: behaviors,
            preAssemble: nil,
            postAssemble: postAssemble,
            autoConfigureContainers: true
        )
    }

}
