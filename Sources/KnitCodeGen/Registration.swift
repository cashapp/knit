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
}
