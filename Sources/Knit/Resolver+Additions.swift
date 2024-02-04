//
// Copyright © Block, Inc. All rights reserved.
//

import Swinject

public extension Resolver {

    /// Force unwrap that improves single line error logging to help track test failures
    /// This is used in knit generated type safe functions
    func knitUnwrap<T>(
        _ value: T?,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: Int = #line
    ) -> T {
        guard let unwrapped = value else {
            fatalError("Knit resolver failure for \(function) -> \(T.self) from \(file):\(line)")
        }
        return unwrapped
    }
}
