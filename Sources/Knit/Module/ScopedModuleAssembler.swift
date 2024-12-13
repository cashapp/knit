//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation

/// Module assembly which only allows registering assemblies which target a particular resolver type.
public final class ScopedModuleAssembler<ScopedResolver> {

    public let internalAssembler: ModuleAssembler

    public var resolver: ScopedResolver {
        // swiftlint:disable:next force_cast
        internalAssembler.resolver as! ScopedResolver
    }

    /// The container that registrations have been placed in. Prefer using resolver unless mutable access is required
    public var _container: Container {
        return internalAssembler._container
    }

    @MainActor
    public convenience init(
        parent: ModuleAssembler? = nil,
        _ modules: [any ModuleAssembly],
        overrideBehavior: OverrideBehavior = .defaultOverridesWhenTesting,
        errorFormatter: ModuleAssemblerErrorFormatter = DefaultModuleAssemblerErrorFormatter(),
        behaviors: [Behavior] = [],
        postAssemble: ((Container) -> Void)? = nil,
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
        _modules modules: [any ModuleAssembly],
        overrideBehavior: OverrideBehavior = .defaultOverridesWhenTesting,
        errorFormatter: ModuleAssemblerErrorFormatter = DefaultModuleAssemblerErrorFormatter(),
        behaviors: [Behavior] = [],
        postAssemble: ((Container) -> Void)? = nil
    ) throws {
        // For provided modules, fail early if they are scoped incorrectly
        for assembly in modules {
            let moduleAssemblyType = type(of: assembly)
            if moduleAssemblyType.resolverType != ScopedResolver.self {
                let scopingError = ScopedModuleAssemblerError.incorrectTargetResolver(
                    expected: String(describing: ScopedResolver.self),
                    actual: String(describing: moduleAssemblyType.resolverType)
                )

                throw DependencyBuilderError.assemblyValidationFailure(moduleAssemblyType, reason: scopingError)
            }
        }
        self.internalAssembler = try ModuleAssembler(
            parent: parent,
            _modules: modules,
            overrideBehavior: overrideBehavior,
            assemblyValidation: { moduleAssemblyType in
                guard moduleAssemblyType.resolverType == ScopedResolver.self else {
                    throw ScopedModuleAssemblerError.incorrectTargetResolver(
                        expected: String(describing: ScopedResolver.self),
                        actual: String(describing: moduleAssemblyType.resolverType)
                    )
                }
            },
            errorFormatter: errorFormatter,
            behaviors: behaviors,
            postAssemble: postAssemble
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
