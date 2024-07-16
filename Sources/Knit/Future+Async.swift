//
//  Future+Async.swift
//  Knit
//

import Combine

public extension Future {

    /// Allow `Future`s to be instantiated directly with async closures.
    convenience init(
        async asyncClosure: @escaping (@escaping Future<Output, Failure>.Promise) async -> Void
    ) {
        self.init { promise in
            Task {
                await asyncClosure(promise)
            }
        }
    }

}
