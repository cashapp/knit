//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import Swinject

protocol TestResolver: Knit.Resolver { }

extension Knit.Container<TestResolver>: TestResolver {}

extension ModuleAssembly {

    // Default to TestResolver to prevent needing to always define this
    typealias TargetResolver = TestResolver

}

extension ModuleAssembler {

    @MainActor
    static func testing(
        parent: ModuleAssembler? = nil,
        _ modules: [any ModuleAssembly],
        overrideBehavior: OverrideBehavior = .defaultOverridesWhenTesting,
        assemblyValidation: ((any ModuleAssembly.Type) throws -> Void)? = nil,
        errorFormatter: ModuleAssemblerErrorFormatter = DefaultModuleAssemblerErrorFormatter(),
        postAssemble: ((Swinject.Container) -> Void)? = nil
    ) throws -> ModuleAssembler {
        try ModuleAssembler(
            parent: parent,
            _modules: modules,
            overrideBehavior: overrideBehavior,
            assemblyValidation: assemblyValidation,
            errorFormatter: errorFormatter, 
            preAssemble: { container in
                // Automatically add the registration for `Container<TestResolver>`
                Knit.Container<TestResolver>._instantiateAndRegister(_swinjectContainer: container)
            },
            postAssemble: postAssemble
        )
    }

}
