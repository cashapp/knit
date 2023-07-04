public struct Registration: Equatable, Codable {

    public var service: String

    public var name: String?

    public var accessLevel: AccessLevel

    /// Argument types required to resolve the registration
    public var arguments: [Argument]

    /// This registration is forwarded to another service entry.
    public var isForwarded: Bool

    public init(
        service: String,
        name: String? = nil,
        accessLevel: AccessLevel,
        arguments: [Argument] = [],
        isForwarded: Bool = false
    ) {
        self.service = service
        self.name = name
        self.accessLevel = accessLevel
        self.arguments = arguments
        self.isForwarded = isForwarded
    }

}

extension Registration {
    public struct Argument: Equatable, Codable {
        let name: Name
        let type: String

        init(name: String? = nil, type: String) {
            if let name {
                self.name = .fixed(name)
            } else {
                self.name = .computed
            }
            self.type = type
        }
    }

    public enum Name: Codable, Equatable {
        case fixed(String)
        case computed

        var string: String {
            switch self {
            case let .fixed(value): return value
            case .computed: fatalError("Argument must be resolved to a fixed name")
            }
        }
    }
}

public enum AccessLevel: String, Codable {
    case `public`
    case `internal`
    case hidden
}
