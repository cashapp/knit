public struct Registration {

    public var service: String

    public var name: String?

    public var accessLevel: AccessLevel

    public init(
        service: String,
        name: String?,
        accessLevel: AccessLevel
    ) {
        self.service = service
        self.name = name
        self.accessLevel = accessLevel
    }

}

public enum AccessLevel {
    case `public`
    case `internal`
    case hidden
}
