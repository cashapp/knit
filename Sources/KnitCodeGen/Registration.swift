//
// Copyright © Block, Inc. All rights reserved.
//

@preconcurrency import SwiftSyntax

public struct Registration: Equatable, Codable, Sendable {

    public var service: String

    /// The resolution name for this Registration, if specified.
    public var name: String?

    public var accessLevel: AccessLevel

    public let concurrencyModifier: String?

    /// Argument types required to resolve the registration
    public var arguments: [Argument]

    /// This alias for the registration's getter.
    public var getterAlias: String?

    public var ifConfigCondition: ExprSyntax? {
        get {
            ifConfigString.map { ExprSyntax("\(raw: $0)") }
        }
        set {
            ifConfigString = newValue?.description
        }
    }

    // This is used to encode ifConfigCondition since ExprSyntax does not conform to codable
    private var ifConfigString: String?

    /// The Swinject function that was used to register this factory
    public let functionName: FunctionName

    /// System Programming Interface annotation that should be applied to the registration
    public var spi: String?

    public init(
        service: String,
        name: String? = nil,
        accessLevel: AccessLevel = .internal,
        arguments: [Argument] = [],
        concurrencyModifier: String? = nil,
        getterAlias: String? = nil,
        functionName: FunctionName = .register,
        ifConfigCondition: ExprSyntax? = nil,
        spi: String? = nil
    ) {
        self.service = service
        self.name = name
        self.accessLevel = accessLevel
        self.concurrencyModifier = concurrencyModifier
        self.arguments = arguments
        self.getterAlias = getterAlias
        self.functionName = functionName
        self.ifConfigCondition = ifConfigCondition
        self.spi = spi
    }

    /// This registration is forwarded to another service entry.
    var isForwarded: Bool {
        return functionName == .implements
    }

    private enum CodingKeys: String, CodingKey {
        // ifConfigCondition is not encoded since ExprSyntax does not conform to codable
        case service, name, accessLevel, arguments, getterAlias, functionName, concurrencyModifier, spi
        case ifConfigString = "ifConfig"
    }

    var hasRedundantGetter: Bool {
        guard let getterAlias else {
            return false
        }
        return TypeNamer.computedIdentifierName(type: service) == getterAlias
    }

}

extension Registration {

    public struct Argument: Equatable, Codable, Sendable {

        let identifier: Identifier
        let type: String

        init(identifier: String? = nil, type: String) {
            if let identifier {
                self.identifier = .fixed(identifier)
            } else {
                self.identifier = .computed
            }
            self.type = type
        }

        public enum Identifier: Codable, Equatable, Sendable {
            /// Used for arguments defined in `.register` registrations.
            case fixed(String)

            /// Used for arguments provided to `.autoregister` registrations, as those do not receive explicit identifiers.
            case computed
        }

    }

    public enum FunctionName: String, Codable, Sendable {
        case register
        case autoregister
        case registerAbstract
        case implements

        static let standaloneFunctions: Set<FunctionName> = [.register, .autoregister, .registerAbstract]
        static let standaloneNames: Set<String> = Set(standaloneFunctions.map { $0.rawValue })
    }
}
