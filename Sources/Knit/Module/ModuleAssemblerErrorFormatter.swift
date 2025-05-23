//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import Swinject

public protocol ModuleAssemblerErrorFormatter {
    func format(knitError: KnitAssemblyError, dependencyTree: DependencyTree?) -> String
}

extension ModuleAssemblerErrorFormatter {

    func format(error: Error, dependencyTree: DependencyTree?) -> String {
        if let abstract = error as? AbstractRegistrationErrors {
            return format(knitError: .abstractList(abstract), dependencyTree: dependencyTree)
        } else if let abstract = error as? AbstractRegistrationError {
            return format(knitError: .abstract(abstract), dependencyTree: dependencyTree)
        } else if let scoped = error as? ScopedModuleAssemblerError {
            return format(knitError: .scoped(scoped), dependencyTree: dependencyTree)
        } else if let builder = error as? DependencyBuilderError {
            return format(knitError: .dependencyBuilder(builder), dependencyTree: dependencyTree)
        } else {
            // Crash on unexpected errors, new errors should be added to KnitAssemblyError as they are introduced
            fatalError("Unexpected error thrown during Knit graph construction: \(error.localizedDescription)")
        }
    }
}

public struct DefaultModuleAssemblerErrorFormatter: ModuleAssemblerErrorFormatter {

    public init() {}

    public func format(knitError: KnitAssemblyError, dependencyTree: DependencyTree?) -> String {
        let info = "Error creating ModuleAssembler. Please make sure all necessary assemblies are provided."
        switch knitError {
        case let .abstractList(abstractErrors):
            let messages = abstractErrors.errors.map { abstractError in
                let assemblyName = abstractError.file.replacingOccurrences(of: ".swift", with: "")
                if let path = dependencyTree?.sourcePathString(moduleName: assemblyName) {
                    return "\(abstractError.localizedDescription)\n\(path)"
                } else {
                    return abstractError.localizedDescription
                }
            }
            return "\(messages.joined(separator: "\n"))\n\(info)"
        default:
            return "Error: \(knitError.localizedDescription)\n\(info)"
        }
    }

}

public enum KnitAssemblyError {
    
    /// An error that occured while the DependencyBuilder was building the tree
    case dependencyBuilder(DependencyBuilderError)

    /// An error related to validating the scoping rules
    case scoped(ScopedModuleAssemblerError)

    /// List of errors related to abstract registrations
    case abstractList(AbstractRegistrationErrors)

    /// A single abstract registration error
    case abstract(AbstractRegistrationError)

    public var localizedDescription: String {
        switch self {
        case let .dependencyBuilder(dependencyBuilderError):
            return dependencyBuilderError.localizedDescription
        case let .scoped(scopedModuleAssemblerError):
            return scopedModuleAssemblerError.localizedDescription
        case let .abstractList(abstractRegistrationErrors):
            return abstractRegistrationErrors.localizedDescription
        case let .abstract(abstractError):
            return abstractError.localizedDescription
        }
    }
}
