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

    /// This registration's getter setting.
    public var getterConfig: Set<GetterConfig>

    public var ifConfigCondition: ExprSyntax?
    
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
        getterConfig: Set<GetterConfig> = GetterConfig.default,
        functionName: FunctionName = .register,
        spi: String? = nil
    ) {
        self.service = service
        self.name = name
        self.accessLevel = accessLevel
        self.concurrencyModifier = concurrencyModifier
        self.arguments = arguments
        self.getterConfig = getterConfig
        self.functionName = functionName
        self.spi = spi
    }

    /// This registration is forwarded to another service entry.
    var isForwarded: Bool {
        return functionName == .implements
    }

    private enum CodingKeys: CodingKey {
        // ifConfigCondition is not encoded since ExprSyntax does not conform to codable
        case service, name, accessLevel, arguments, getterConfig, functionName, concurrencyModifier, spi
    }

    var namedGetterConfig: GetterConfig? {
        getterConfig.first(where: { $0.isNamed })
    }

    var hasRedundantGetter: Bool {
        guard let namedGetterConfig, case let GetterConfig.identifiedGetter(name) = namedGetterConfig else {
            return false
        }
        return TypeNamer.computedIdentifierName(type: service) == name
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
