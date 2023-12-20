//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation

/// Module assembly which only allows registering assemblies which target a particular resolver type.
public final class ScopedModuleAssembler<ScopedResolver> {

    public let internalAssembler: ModuleAssembler
    
    /// Cast and return the swinject resolver to the expected type
    public var resolver: ScopedResolver {
        // swiftlint:disable:next force_cast
        internalAssembler.resolver as! ScopedResolver
    }

    /// Return a weakly wrapped version of the scoped resolver.
    /// This resolver will only function while the ModuleAssembler remains in memory
    public var weakResolver: ScopedResolver {
        // swiftlint:disable:next force_cast
        return WeakResolver(container: internalAssembler.container) as! ScopedResolver
    }

    public convenience init(
        parent: ModuleAssembler? = nil,
        _ modules: [any Assembly],
        defaultOverrides: DefaultOverrideState = .whenTesting,
        postAssemble: ((Container) -> Void)? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        do {
            try self.init(
                parent: parent,
                _modules: modules,
                defaultOverrides: defaultOverrides,
                postAssemble: postAssemble
            )
        } catch {
            fatalError(
                error.localizedDescription,
                file: file,
                line: line
            )
        }
    }

    // Internal required init that throws rather than fatal errors
    required init(
        parent: ModuleAssembler? = nil,
        _modules modules: [any Assembly],
        defaultOverrides: DefaultOverrideState = .whenTesting,
        postAssemble: ((Container) -> Void)? = nil
    ) throws {
        self.internalAssembler = try ModuleAssembler(
            parent: parent,
            _modules: modules,
            defaultOverrides: defaultOverrides,
            assemblyValidation: { moduleAssemblyType in
                guard moduleAssemblyType.resolverType == ScopedResolver.self else {
                    throw ScopedModuleAssemblerError.incorrectTargetResolver(
                        expected: String(describing: ScopedResolver.self),
                        actual: String(describing: moduleAssemblyType.resolverType)
                    )
                }
            },
            postAssemble: postAssemble
        )
    }

}

// MARK: - Errors

enum ScopedModuleAssemblerError: LocalizedError {

    case incorrectTargetResolver(expected: String, actual: String)

    var errorDescription: String? {
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
