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

    public init(
        parent: ModuleAssembler? = nil,
        _ modules: [any Assembly],
        defaultOverrides: DefaultOverrideState = .whenTesting,
        postAssemble: ((Container) -> Void)? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        self.internalAssembler = ModuleAssembler(
            parent: parent,
            modules,
            defaultOverrides: defaultOverrides,
            postAssemble: postAssemble,
            file: file,
            line: line
        )

        let invalidAssemblies = internalAssembler.registeredModules.filter({
            $0.resolverType != ScopedResolver.self
        })

        if invalidAssemblies.count > 0 {
            // Crash if any unexpected module assemblies are registered
            let assemblyLines = invalidAssemblies.map { assemblyType in
                let pathString = internalAssembler.builder.sourcePathString(moduleType: assemblyType)
                return "\n\(assemblyType) - Target resolver: \(assemblyType.resolverType)\n\(pathString)"

            }
            fatalError(
                "Registered \(invalidAssemblies.count) invalid assembly(s). " +
                "Expected target resolver: \(ScopedResolver.self)" +
                assemblyLines.joined(),
                file: file,
                line: line
            )
        }
    }

}
