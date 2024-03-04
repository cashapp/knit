//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax

struct KnitDirectives: Codable, Equatable {
    let accessLevel: AccessLevel?
    let getterConfig: Set<GetterConfig>
    let role: AssemblyRole?

    public init(
        accessLevel: AccessLevel? = nil,
        getterConfig: Set<GetterConfig> = [],
        role: AssemblyRole? = nil
    ) {
        self.accessLevel = accessLevel
        self.getterConfig = getterConfig
        self.role = role
    }

    private static let directiveMarker = "@knit"

    static func parse(leadingTrivia: Trivia?) throws -> KnitDirectives {
        guard let leadingTriviaText = leadingTrivia?.description else {
            return .empty
        }
        let matchingLine = leadingTriviaText
            .components(separatedBy: .newlines)
            .filter { $0.contains(Self.directiveMarker) }
            .first

        guard let directiveLine = matchingLine else {
            return .empty
        }

        var tokens = directiveLine
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty && $0 != "//" }
        guard tokens.first == Self.directiveMarker else {
            return .empty
        }
        tokens = Array(tokens.dropFirst())

        var accessLevel: AccessLevel?
        var getterConfigs: Set<GetterConfig> = []
        var assemblyRole: AssemblyRole?

        for token in tokens {
            let parsed = try parse(token: token)
            if let level = parsed.accessLevel {
                accessLevel = level
            }
            if let role = parsed.role {
                assemblyRole = role
            }
            if let getter = parsed.getterConfig {
                getterConfigs.insert(getter)
            }
        }

        return KnitDirectives(accessLevel: accessLevel, getterConfig: getterConfigs, role: assemblyRole)
    }

    private static func parse(token: String) throws -> ParseResult {
        if let accessLevel = AccessLevel(rawValue: token) {
            return .init(accessLevel: accessLevel)
        }
        if let role = AssemblyRole(rawValue: token) {
            return .init(role: role)
        }
        if token == "getter-callAsFunction" {
            return .init(getterConfig: .callAsFunction)
        }
        if let nameMatch = getterNamedRegex.firstMatch(in: token, range: NSMakeRange(0, token.count)) {
            if nameMatch.numberOfRanges >= 2, nameMatch.range(at: 1).location != NSNotFound {
                var range = nameMatch.range(at: 1)
                range = NSRange(location: range.location + 2, length: range.length - 4)
                let name = (token as NSString).substring(with: range)
                return .init(getterConfig: .identifiedGetter(name))
            }
            return .init(getterConfig: .identifiedGetter(nil))
        }
        
        throw Error.unexpectedToken(token: token)
    }

    static var empty: KnitDirectives {
        return .init(accessLevel: nil, getterConfig: [], role: nil)
    }

    private static let getterNamedRegex = try! NSRegularExpression(pattern: "getter-named(\\(\"\\w*\"\\))?")
}

extension KnitDirectives {
    enum Error: LocalizedError {
        case unexpectedToken(token: String)

        var errorDescription: String? {
            switch self {
            case let .unexpectedToken(token):
                return "Unexpected knit comment rule \(token)"
            }
        }
    }
}

public enum GetterConfig: Codable, Equatable, Hashable {
    /// Only the `callAsFunction()` accessor is generated.
    case callAsFunction
    /// Only the identified getter is generated.
    case identifiedGetter(_ name: String?)

    /// Centralized control of the default behavior.
    public static var `default`: Set<GetterConfig> = [.identifiedGetter(nil)]

    public static var both: Set<GetterConfig> = [.callAsFunction, .identifiedGetter(nil)]

    public var isNamed: Bool {
        switch self {
        case .identifiedGetter: return true
        default: return false
        }
    }
}

public enum AccessLevel: String, CaseIterable, Codable {
    case `public`
    case `internal`
    case hidden
    case ignore

    /// Centralized control of the default behavior.
    public static var `default`: AccessLevel = .internal
}

public enum AssemblyRole: String, CaseIterable, Codable {

    /// The primary assembly for the module
    case primary

    /// Any secondary role for the module
    case secondary

    /// Centralized control of the default behavior.
    public static var `default`: AssemblyRole = .primary
}

private struct ParseResult {
    let accessLevel: AccessLevel?
    let getterConfig: GetterConfig?
    let role: AssemblyRole?

    init(
        accessLevel: AccessLevel? = nil,
        getterConfig: GetterConfig? = nil,
        role: AssemblyRole? = nil
    ) {
        self.accessLevel = accessLevel
        self.getterConfig = getterConfig
        self.role = role
    }
}
