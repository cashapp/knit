//
// Copyright © Block, Inc. All rights reserved.
//

import Swinject

public extension Swinject.Resolver {

    /// Force unwrap that improves single line error logging to help track test failures
    /// This is used in knit generated type safe functions
    func knitUnwrap<T>(
        _ value: T?,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        // Allow for an additional frame of the call-stack for better context
        callsiteFile: StaticString,
        callsiteFunction: StaticString,
        callsiteLine: UInt
    ) -> T {
        guard let unwrapped = value else {
            let dependencyTree = self.resolve(DependencyTree.self)
            let graph = dependencyTree.map { "Dependency Graph:\n\($0.debugDescription)" } ?? ""
            fatalError("""
                Knit resolver failure for \(function) -> \(T.self) from \(file):\(line)
                Called by \(callsiteFunction) from \(callsiteFile):\(callsiteLine)
                \(graph)
                """)
        }
        return unwrapped
    }
}

// MARK: -

public extension Knit.Resolver {

    /// Force unwrap that improves single line error logging to help track test failures
    /// This is used in knit generated type safe functions
    func knitUnwrap<T>(
        _ value: T?,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        // Allow for an additional frame of the call-stack for better context
        callsiteFile: StaticString,
        callsiteFunction: StaticString,
        callsiteLine: UInt
    ) -> T {
        self.unsafeResolver.knitUnwrap(
            value,
            file: file,
            function: function,
            line: line,
            callsiteFile: callsiteFile,
            callsiteFunction: callsiteFunction,
            callsiteLine: callsiteLine
        )
    }

}
