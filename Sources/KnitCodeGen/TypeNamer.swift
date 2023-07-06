// Created by Alexander skorulis on 6/7/2023.
// Copyright © Square, Inc. All rights reserved. 

import Foundation

enum TypeNamer {

    /**
     Creates a name for a given Type signature.
     The resulting name can be safely used as an identifier in Swift (does not use reserved characters).

     See TypeNamerTests unit tests for examples.
     */
    static func computedIdentifierName(type: String) -> String {
        let type = sanitizeType(type: type)
        if type.uppercased() == type {
            return type.lowercased()
        }
        return type.prefix(1).lowercased() + type.dropFirst()
    }

    /// Simplifies the type name and removes invalid characters
    private static func sanitizeType(type: String) -> String {
        if isClosure(type: type) {
            // The naming doesn't work for function types, just return closure
            return "closure"
        }
        let removedCharacters = CharacterSet(charactersIn: "?[]")
        var type = type.components(separatedBy: removedCharacters).joined(separator: "")
        let regex = try! NSRegularExpression(pattern: "<.*>")
        if let match = regex.firstMatch(in: type, range: .init(location: 0, length: type.count)) {
            type = (type as NSString).replacingCharacters(in: match.range, with: "")
        }
        if let dotIndex = type.firstIndex(of: ".") {
            let nameStart = type.index(after: dotIndex)
            type = String(type[nameStart...])
        }

        return type
    }

    static func isClosure(type: String) -> Bool {
        return type.contains("->")
    }

}
