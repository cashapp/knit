//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation

public enum TypeNamer {

    /**
     Creates a name for a given Type signature.
     The resulting name can be safely used as an identifier in Swift (does not use reserved characters).

     See TypeNamerTests unit tests for examples.
     */
    public static func computedIdentifierName(type: String) -> String {
        let type = sanitizeType(type: type, keepGenerics: false)
        let lowercaseIndex = type.firstIndex { $0.isLowercase }
        if let lowercaseIndex {
            let chars = max(type.distance(from: type.startIndex, to: lowercaseIndex) - 1, 1)
            return type.prefix(chars).lowercased() + type.dropFirst(chars)
        } else {
            return type.lowercased()
        }
    }

    /// Simplifies the type name and removes invalid characters
    public static func sanitizeType(type: String, keepGenerics: Bool) -> String {
        if isClosure(type: type) {
            // The naming doesn't work for function types, just return closure
            return "closure"
        }
        // Drop any annotation
        var type = type.replacingOccurrences(of: "any ", with: "")
        let removedCharacters = CharacterSet(charactersIn: "?[]():& ")
        type = type.components(separatedBy: removedCharacters).joined(separator: "")
        let regex = try! NSRegularExpression(pattern: "<.*>")
        let nsString = type as NSString
        if let match = regex.firstMatch(in: type, range: .init(location: 0, length: type.count)) {
            let range = match.range
            let mainType = nsString.replacingCharacters(in: match.range, with: "")
            if keepGenerics {
                var genericName = nsString.substring(
                    with: .init(location: range.location + 1, length: range.length - 2)
                )
                // Handle generic types with multiple parameters
                genericName = genericName
                    .replacingOccurrences(of: ",", with: "_")
                    .replacingOccurrences(of: " ", with: "")
                type = nsString.replacingCharacters(in: match.range, with: "_\(genericName)")
            } else if let suffix = Self.suffixedGenericTypes.first(where: { mainType.hasSuffix($0)} ) {
                let genericName = nsString.substring(
                    with: .init(location: range.location + 1, length: range.length - 2)
                )
                if let mainGeneric = genericName.components(separatedBy: .init(charactersIn: ",")).first {
                    type = sanitizeType(type: mainGeneric, keepGenerics: false) + suffix
                } else {
                    type = mainType
                }
            } else {
                type = mainType
            }
        } else {
            type = type.components(separatedBy: .init(charactersIn: ",")).joined(separator: "")
        }
        if let dotIndex = type.lastIndex(of: ".") {
            let nameStart = type.index(after: dotIndex)
            let lastType = String(type[nameStart...])
            // Types with a Factory subtype should keep the subject of the factory
            if lastType == "Factory" {
                let components = type.components(separatedBy: .init(charactersIn: "."))
                type = components.suffix(2).joined(separator: "")
            } else {
                type = lastType
            }
        }

        return type
    }

    private static let suffixedGenericTypes = ["Publisher", "Subject", "Provider", "Set", "Future"]

    static func isClosure(type: String) -> Bool {
        return type.contains("->")
    }

}
