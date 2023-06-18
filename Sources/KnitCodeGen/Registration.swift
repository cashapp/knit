public struct Registration: Equatable {

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

    /// Generate names for each argument based on the type
    public var namedArguments: [(name: String, type: String)] {
        var result: [(name: String, type: String)] = []
        for argument in arguments {
            let indexID: String
            if (arguments.filter { $0.resolvedName == argument.resolvedName }).count > 1 {
                indexID = (result.filter { $0.type == argument.type }.count + 1).description
            } else {
                indexID = ""
            }
            let name = argument.resolvedName + indexID
            result.append((name, argument.type))
        }
        return result
    }


}

extension Registration {
    public struct Argument: Equatable {
        let name: String?
        let type: String

        init(name: String? = nil, type: String) {
            self.name = name
            self.type = type
        }

        var resolvedName: String {
            if let name {
                return name
            }
            if type.uppercased() == type {
                return type.lowercased()
            }
            return type.prefix(1).lowercased() + type.dropFirst()
        }
    }
}

public enum AccessLevel {
    case `public`
    case `internal`
    case hidden
}
