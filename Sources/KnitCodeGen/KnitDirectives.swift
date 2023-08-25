// Copyright © Square, Inc. All rights reserved.

import Foundation
import SwiftSyntax

struct KnitDirectives: Codable, Equatable {
    let accessLevel: AccessLevel?
    let getterConfig: Set<GetterConfig>

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

        for token in tokens {
            let parsed = try parse(token: token)
            if let level = parsed.accessLevel {
                accessLevel = level
            }
            if let getter = parsed.getterConfig {
                getterConfigs.insert(getter)
            }
        }

        return KnitDirectives(accessLevel: accessLevel, getterConfig: getterConfigs)
    }

    static func parse(token: String) throws -> (accessLevel: AccessLevel?, getterConfig: GetterConfig?) {
        if let accessLevel = AccessLevel(rawValue: token) {
            return (accessLevel, nil)
        }
        if token == "getter-callAsFunction" {
            return (nil, .callAsFunction)
        }
        if let nameMatch = getterNamedRegex.firstMatch(in: token, range: NSMakeRange(0, token.count)) {
            if nameMatch.numberOfRanges >= 2, nameMatch.range(at: 1).location != NSNotFound {
                var range = nameMatch.range(at: 1)
                range = NSRange(location: range.location + 2, length: range.length - 4)
                let name = (token as NSString).substring(with: range)
                return (nil, .identifiedGetter(name))
            }
            return (nil, .identifiedGetter(nil))
        }
        
        throw Error.unexpectedToken(token: token)
    }

    static var empty: KnitDirectives {
        return .init(accessLevel: nil, getterConfig: [])
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

    /// Centralized control of the default behavior.
    public static var `default`: AccessLevel = .internal
}
