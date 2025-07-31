//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import Swinject

/// Module assembly which only allows registering assemblies which target a particular resolver type.
public final class ScopedModuleAssembler<TargetResolver: Resolver> {

    public let internalAssembler: ModuleAssembler

    public var resolver: TargetResolver {
        internalAssembler.resolver.resolve(Knit.Container<TargetResolver>.self)!.resolver
    }

    /// Access the underlying Swinject.Resolver to resolve without type safety.
    var unsafeResolver: Swinject.Resolver {
        internalAssembler.resolver
    }

    @MainActor
    public convenience init(
        parent: ModuleAssembler? = nil,
        _ modules: [any ModuleAssembly<TargetResolver>],
        overrideBehavior: OverrideBehavior = .defaultOverridesWhenTesting,
        errorFormatter: ModuleAssemblerErrorFormatter = DefaultModuleAssemblerErrorFormatter(),
        behaviors: [Behavior] = [],
        postAssemble: ((Container<TargetResolver>) -> Void)? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        do {
            try self.init(
                parent: parent,
                _modules: modules,
                overrideBehavior: overrideBehavior,
                behaviors: behaviors,
                postAssemble: postAssemble
            )
        } catch {
            let message = errorFormatter.format(error: error, dependencyTree: nil)
            fatalError(
                message,
                file: file,
                line: line
            )
        }
    }

    // Internal required init that throws rather than fatal errors
    @MainActor
    required init(
        parent: ModuleAssembler? = nil,
        _modules modules: [any ModuleAssembly<TargetResolver>],
        overrideBehavior: OverrideBehavior = .defaultOverridesWhenTesting,
        errorFormatter: ModuleAssemblerErrorFormatter = DefaultModuleAssemblerErrorFormatter(),
        behaviors: [Behavior] = [],
        postAssemble: ((Container<TargetResolver>) -> Void)? = nil
    ) throws {
        // For provided modules, fail early if they are scoped incorrectly
        for assembly in modules {
            if !assembly.usesResolver(TargetResolver.self) {
                let scopingError = ScopedModuleAssemblerError.incorrectTargetResolver(
                    expected: String(describing: TargetResolver.self),
                    actual: String(describing: type(of: assembly).resolverType)
                )

                throw DependencyBuilderError.assemblyValidationFailure(type(of: assembly), reason: scopingError)
            }
        }
        self.internalAssembler = try ModuleAssembler(
            parent: parent,
            _modules: modules,
            overrideBehavior: overrideBehavior,
            assemblyValidation: { moduleAssemblyType in
                guard moduleAssemblyType.resolverType.equal(TargetResolver.self) else {
                    throw ScopedModuleAssemblerError.incorrectTargetResolver(
                        expected: String(describing: TargetResolver.self),
                        actual: String(describing: moduleAssemblyType.resolverType)
                    )
                }
            },
            errorFormatter: errorFormatter,
            behaviors: behaviors,
            preAssemble: { container in
                // Register a Container for the the current-scoped `TargetResolver`
                container.resolve(ContainerManager.self)!.register(TargetResolver.self)
            },
            postAssemble: { swinjectContainer in
                let container = swinjectContainer.resolve(Container<TargetResolver>.self)!
                postAssemble?(container)
            },
            autoConfigureContainers: false
        )
    }

}

// MARK: - Errors

public enum ScopedModuleAssemblerError: LocalizedError {

    case incorrectTargetResolver(expected: String, actual: String)

    public var errorDescription: String? {
        switch self {
        case let .incorrectTargetResolver(expected, actual):
            return """
                The ModuleAssembly's TargetResolver is incorrect.
                Expected: \(expected)
                Actual: \(actual)
                """
        }
    }
}
