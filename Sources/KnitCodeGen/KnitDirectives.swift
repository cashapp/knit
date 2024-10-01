//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax

public struct KnitDirectives: Codable, Equatable {
    var accessLevel: AccessLevel?
    var getterConfig: Set<GetterConfig>
    var moduleName: String?
    var spi: String?

    public init(
        accessLevel: AccessLevel? = nil,
        getterConfig: Set<GetterConfig> = [],
        moduleName: String? = nil,
        spi: String? = nil
    ) {
        self.accessLevel = accessLevel
        self.getterConfig = getterConfig
        self.moduleName = moduleName
        self.spi = spi
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
        
        var result = KnitDirectives()

        for token in tokens {
            let parsed = try parse(token: token)
            if let level = parsed.accessLevel {
                result.accessLevel = level
            }
            if let name = parsed.moduleName {
                result.moduleName = name
            }
            for getter in parsed.getterConfig {
                result.getterConfig.insert(getter)
            }
            if let spi = parsed.spi {
                if result.spi != nil {
                    throw Error.duplicateSPI(name: spi)
                }
                result.spi = spi
            }
        }

        return result
    }

    static func parse(token: String) throws -> KnitDirectives {
        if let accessLevel = AccessLevel(rawValue: token) {
            return KnitDirectives(accessLevel: accessLevel)
        }
        if token == "getter-callAsFunction" {
            return KnitDirectives(getterConfig: [.callAsFunction])
        }
        if let nameMatch = getterNamedRegex.firstMatch(in: token, range: NSMakeRange(0, token.count)) {
            if nameMatch.numberOfRanges >= 2, nameMatch.range(at: 1).location != NSNotFound {
                var range = nameMatch.range(at: 1)
                range = NSRange(location: range.location + 2, length: range.length - 4)
                let name = (token as NSString).substring(with: range)
                return KnitDirectives(getterConfig: [.identifiedGetter(name)])
            }
            return KnitDirectives(getterConfig: [.identifiedGetter(nil)])
        }
        if let nameMatch = moduleNameRegex.firstMatch(in: token, range: NSMakeRange(0, token.count)) {
            if nameMatch.numberOfRanges >= 2, nameMatch.range(at: 1).location != NSNotFound {
                var range = nameMatch.range(at: 1)
                range = NSRange(location: range.location + 2, length: range.length - 4)
                let name = (token as NSString).substring(with: range)
                return KnitDirectives(moduleName: name)
            }
        }
        if let spiMatch = spiRegex.firstMatch(in: token, range: NSMakeRange(0, token.count)) {
            if spiMatch.numberOfRanges >= 2, spiMatch.range(at: 1).location != NSNotFound {
                var range = spiMatch.range(at: 1)
                range = NSRange(location: range.location + 1, length: range.length - 2)
                let spi = (token as NSString).substring(with: range)
                return KnitDirectives(spi: spi)
            }
        }

        throw Error.unexpectedToken(token: token)
    }

    static var empty: KnitDirectives {
        return .init()
    }

    private static let getterNamedRegex = try! NSRegularExpression(pattern: "getter-named(\\(\"\\w*\"\\))?")
    private static let moduleNameRegex = try! NSRegularExpression(pattern: "module-name(\\(\"\\w*\"\\))")
    private static let spiRegex = try!  NSRegularExpression(pattern: "@_spi(\\(\\w*\\))")
}

extension KnitDirectives {
    enum Error: LocalizedError {
        case unexpectedToken(token: String)
        case duplicateSPI(name: String)

        var errorDescription: String? {
            switch self {
            case let .unexpectedToken(token):
                return "Unexpected knit comment rule \(token)"
            case .duplicateSPI:
                return "Duplicate @_spi annotations are not supported"
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
