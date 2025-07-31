//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import Swinject

open class Resolver {

    private weak var _swinjectContainer: Swinject.Container?

    /// Returns `true` if the backing container is still available in memory, otherwise `false`.
    public var isAvailable: Bool {
        _swinjectContainer != nil
    }

    // MARK: - Swinject.Resolver

    public func unsafeResolver(file: StaticString, function: StaticString, line: UInt) -> Swinject.Resolver {
        _unwrappedSwinjectContainer(file: file, function: function, line: line)
    }

    public required init(_swinjectContainer: Swinject.Container) {
        self._swinjectContainer = _swinjectContainer
    }

    internal static func equal(_ resolverType: Resolver.Type) -> Bool {
        return self == resolverType
    }

    public class func `is`(_ resolverType: Resolver.Type) -> Bool {
        return self == resolverType
    }
}

extension Resolver {

    // Force unwraps the weak Container
    func _unwrappedSwinjectContainer(
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) -> Swinject.Container {
        guard let _swinjectContainer else {
            fatalError(
                "\(function) incorrectly accessed the container for \(self) which has already been released",
                file: file,
                line: line
            )
        }
        return _swinjectContainer
    }

}
