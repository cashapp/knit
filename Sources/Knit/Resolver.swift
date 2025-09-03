//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import Swinject

/// This effectively removes all the unsafe resolve methods from the publicly available API.
public protocol Resolver: AnyObject {

    /// Returns `true` if the backing container is still available in memory, otherwise `false`.
    var isAvailable: Bool { get }

    func unsafeResolver(file: StaticString, function: StaticString, line: UInt) -> SwinjectResolver

    init(_swinjectContainer: SwinjectContainer)

    /// Resolvers require a manual implementation that matches the inheritance structure of the Resolver
    /// If ResolverB inherits from ResolverA then the ResolverB inherits function should match this
    /// Example:
    /// public func ResolverB: ResolverA {
    ///   static func inherits(from resolverType: Resolver.Type) -> Bool {
    ///    return self == resolverType || resolverType == ResolverA.self
    ///   }
    /// }
    static func inherits(from resolverType: Resolver.Type) -> Bool

}

/// Default Resolver implementation. Designed to be inherited from
open class BaseResolver: Resolver {

    private weak var _swinjectContainer: SwinjectContainer?

    /// Returns `true` if the backing container is still available in memory, otherwise `false`.
    public var isAvailable: Bool {
        _swinjectContainer != nil
    }

    // MARK: - SwinjectResolver

    public func unsafeResolver(file: StaticString, function: StaticString, line: UInt) -> SwinjectResolver {
        _unwrappedSwinjectContainer(file: file, function: function, line: line)
    }

    public required init(_swinjectContainer: SwinjectContainer) {
        self._swinjectContainer = _swinjectContainer
    }

    /// Default implementation uses pure equality
    open class func inherits(from resolverType: Resolver.Type) -> Bool {
        return self == resolverType
    }

    // Force unwraps the weak Container
    func _unwrappedSwinjectContainer(
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line
    ) -> SwinjectContainer {
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
