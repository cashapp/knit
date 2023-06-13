public struct Registration: Equatable {

    public var service: String

    public var name: String?

    public var accessLevel: AccessLevel

    /// This registration is forwarded to another service entry.
    public var isForwarded: Bool

    public init(
        service: String,
        name: String?,
        accessLevel: AccessLevel,
        isForwarded: Bool
    ) {
        self.service = service
        self.name = name
        self.accessLevel = accessLevel
        self.isForwarded = isForwarded
    }

}

public enum AccessLevel {
    case `public`
    case `internal`
    case hidden
}
