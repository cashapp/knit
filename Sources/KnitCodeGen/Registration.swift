public struct Registration: Equatable {

    public var service: String

    public var name: String?

    public var accessLevel: AccessLevel

    /// Argument types required to resolve the registration
    public var arguments: [String]

    /// This registration is forwarded to another service entry.
    public var isForwarded: Bool

    public init(
        service: String,
        name: String? = nil,
        accessLevel: AccessLevel,
        arguments: [String] = [],
        isForwarded: Bool = false
    ) {
        self.service = service
        self.name = name
        self.accessLevel = accessLevel
        self.arguments = arguments
        self.isForwarded = isForwarded
    }

    /// Generate names for each argument based on the type
    public var namedArguments: [(name: String, type: String)] {
        var result: [(name: String, type: String)] = []
        for type in arguments {
            let indexID: String
            if (arguments.filter { $0 == type }).count > 1 {
                indexID = (result.filter { $0.type == type }.count + 1).description
            } else {
                indexID = ""
            }
            let name = Self.name(argType: type) + indexID
            result.append((name, type))
        }
        return result
    }

    private static func name(argType: String) -> String {
        if argType.uppercased() == argType {
            return argType.lowercased()
        }
        return argType.prefix(1).lowercased() + argType.dropFirst()
    }
}

public enum AccessLevel {
    case `public`
    case `internal`
    case hidden
}
