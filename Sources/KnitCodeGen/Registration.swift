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
        let name: String?
        let type: String

        init(name: String? = nil, type: String) {
            self.name = name
            self.type = type
        }
    }
}

public enum AccessLevel: String, Codable {
    case `public`
    case `internal`
    case hidden
}
