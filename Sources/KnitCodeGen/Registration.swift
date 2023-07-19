public struct Registration: Equatable, Codable {

    public var service: String

    /// The resolution name for this Registration, if specified.
    public var name: String?

    public var accessLevel: AccessLevel

    /// Argument types required to resolve the registration
    public var arguments: [Argument]

    /// This registration is forwarded to another service entry.
    public var isForwarded: Bool

    /// This registration's getter setting.
    public var getterConfig: GetterConfig

    public init(
        service: String,
        name: String? = nil,
        accessLevel: AccessLevel,
        arguments: [Argument] = [],
        isForwarded: Bool = false,
        getterConfig: GetterConfig = .default
    ) {
        self.service = service
        self.name = name
        self.accessLevel = accessLevel
        self.arguments = arguments
        self.isForwarded = isForwarded
        self.getterConfig = getterConfig
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

    public enum GetterConfig: Codable {
        /// Only the `callAsFunction()` accessor is generated.
        case callAsFunction
        /// Only the identified getter is generated.
        case identifiedGetter
        /// Both the identified getter and the `callAsFunction()` accessors are generated.
        case both

        /// Centralized control of the default behavior.
        public static var `default`: GetterConfig = .identifiedGetter
    }

}

public enum AccessLevel: String, Codable {
    case `public`
    case `internal`
    case hidden
}
