//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax

public struct KnitDirectives: Codable, Equatable, Sendable {
    var accessLevel: AccessLevel?
    var getterAlias: String?
    var moduleName: String?
    var spi: String?
    // Custom tags that are not consumed by Knit
    var custom: [String] = []

    /// When true the code gen will not create the additional methods to improve assembler performance
    var disablePerformanceGen: Bool

    public init(
        accessLevel: AccessLevel? = nil,
        custom: [String] = [],
        disablePerformanceGen: Bool = false,
        getterAlias: String? = nil,
        moduleName: String? = nil,
        spi: String? = nil
    ) {
        self.accessLevel = accessLevel
        self.disablePerformanceGen = disablePerformanceGen
        self.getterAlias = getterAlias
        self.moduleName = moduleName
        self.spi = spi
        self.custom = custom
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
            if parsed.disablePerformanceGen {
                result.disablePerformanceGen = true
            }
            result.getterAlias = parsed.getterAlias
            if let spi = parsed.spi {
                if result.spi != nil {
                    throw Error.duplicateSPI(name: spi)
                }
                result.spi = spi
            }
            result.custom.append(contentsOf: parsed.custom)
        }

        return result
    }

    static func parse(token: String) throws -> KnitDirectives {
        if let accessLevel = AccessLevel(rawValue: token) {
            return KnitDirectives(accessLevel: accessLevel)
        }
        if token == "disable-performance-gen" {
            return KnitDirectives(disablePerformanceGen: true)
        }
        if let nameMatch = getterAliasRegex.firstMatch(in: token, range: NSMakeRange(0, token.count)) {
            if nameMatch.numberOfRanges >= 2, nameMatch.range(at: 1).location != NSNotFound {
                var range = nameMatch.range(at: 1)
                range = NSRange(location: range.location + 2, length: range.length - 4)
                let name = (token as NSString).substring(with: range)
                return KnitDirectives(getterAlias: name)
            }
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
        if let tagMatch = tagRegex.firstMatch(in: token, range: NSMakeRange(0, token.count)) {
            if tagMatch.numberOfRanges >= 2, tagMatch.range(at: 1).location != NSNotFound {
                var range = tagMatch.range(at: 1)
                range = NSRange(location: range.location + 2, length: range.length - 4)
                let custom = (token as NSString).substring(with: range)
                return KnitDirectives(custom: [custom])
            }
        }

        throw Error.unexpectedToken(token: token)
    }

    static var empty: KnitDirectives {
        return .init()
    }

    private static let getterAliasRegex = try! NSRegularExpression(pattern: "alias(\\(\"\\w*\"\\))")
    private static let moduleNameRegex = try! NSRegularExpression(pattern: "module-name(\\(\"\\w*\"\\))")
    private static let spiRegex = try! NSRegularExpression(pattern: "@_spi(\\(\\w*\\))")
    private static let tagRegex = try! NSRegularExpression(pattern: "tag(\\(\"\\w*\"\\))?")
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

public enum AccessLevel: String, CaseIterable, Codable, Sendable {
    case `public`
    case `internal`
    case hidden
    case ignore

    /// Centralized control of the default behavior.
    public static let `default`: AccessLevel = .internal
}
