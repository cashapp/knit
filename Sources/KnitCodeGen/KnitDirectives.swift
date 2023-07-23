// Copyright © Square, Inc. All rights reserved.

import SwiftSyntax

struct KnitDirectives: Codable {
    let accessLevel: AccessLevel?
    let getterConfig: GetterConfig?

    static func parse(leadingTrivia: Trivia?) -> KnitDirectives {
        guard let leadingTriviaText = leadingTrivia?.description, leadingTriviaText.contains("@knit") else {
            return .empty
        }
        let accessLevel: AccessLevel? = AccessLevel.allCases.first { leadingTriviaText.contains($0.rawValue) }

        let identifiedGetterOnly = leadingTriviaText.contains("getter-named")
        let callAsFuncOnly =       leadingTriviaText.contains("getter-callAsFunction")

        let getterConfig: GetterConfig?
        switch (identifiedGetterOnly, callAsFuncOnly) {
        case (false, false):
            getterConfig = nil
        case (true, false):
            getterConfig = .identifiedGetter
        case (false, true):
            getterConfig = .callAsFunction
        case (true, true):
            getterConfig = .both
        }

        return KnitDirectives(accessLevel: accessLevel, getterConfig: getterConfig)
    }

    static var empty: KnitDirectives {
        return .init(accessLevel: nil, getterConfig: nil)
    }
}


public enum GetterConfig: Codable, CaseIterable {
    /// Only the `callAsFunction()` accessor is generated.
    case callAsFunction
    /// Only the identified getter is generated.
    case identifiedGetter
    /// Both the identified getter and the `callAsFunction()` accessors are generated.
    case both

    /// Centralized control of the default behavior.
    public static var `default`: GetterConfig = .identifiedGetter
}

public enum AccessLevel: String, CaseIterable, Codable {
    case `public`
    case `internal`
    case hidden

    /// Centralized control of the default behavior.
    public static var `default`: AccessLevel = .internal
}
