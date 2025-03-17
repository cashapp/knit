//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import Swinject

/// This effectively removes all the unsafe resolve methods from the publicly available API.
public protocol Resolver: AnyObject {

    /// Returns `true` if the backing container is still available in memory, otherwise `false`.
    var isAvailable: Bool { get }

    var unsafeResolver: Swinject.Resolver { get }

}
