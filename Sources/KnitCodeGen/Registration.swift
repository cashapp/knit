//
// Copyright © Block, Inc. All rights reserved.
//

import SwiftSyntax

public struct Registration: Equatable, Codable {

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

    public init(
        service: String,
        name: String? = nil,
        accessLevel: AccessLevel = .internal,
        arguments: [Argument] = [],
        concurrencyModifier: String? = nil,
        getterConfig: Set<GetterConfig> = GetterConfig.default,
        functionName: FunctionName = .register
    ) {
        self.service = service
        self.name = name
        self.accessLevel = accessLevel
        self.concurrencyModifier = concurrencyModifier
        self.arguments = arguments
        self.getterConfig = getterConfig
        self.functionName = functionName
    }

    /// This registration is forwarded to another service entry.
    var isForwarded: Bool {
        return functionName == .implements
    }

    private enum CodingKeys: CodingKey {
        // ifConfigCondition is not encoded since ExprSyntax does not conform to codable
        case service, name, accessLevel, arguments, getterConfig, functionName, concurrencyModifier
    }

}

extension Registration {

    public struct Argument: Equatable, Codable {

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

        public enum Identifier: Codable, Equatable {
            case fixed(String)
            case computed
        }

    }

    public enum FunctionName: String, Codable {
        case register
        case autoregister
        case registerAbstract
        case implements

        static let standaloneFunctions: Set<FunctionName> = [.register, .autoregister, .registerAbstract]
        static let standaloneNames: Set<String> = Set(standaloneFunctions.map { $0.rawValue })
    }
}
