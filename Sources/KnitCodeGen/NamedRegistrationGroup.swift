//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax

/// Collection of named registrations for a single service.
struct NamedRegistrationGroup {

    let service: String
    let registrations: [Registration]

    /// Group named registrations by service name
    static func make(from: [Registration]) -> [NamedRegistrationGroup] {
        let withNames = from.filter { $0.name != nil }
        let dict = Dictionary(grouping: withNames, by: {$0.service})
        return dict.map { key, value in
            return NamedRegistrationGroup(service: key, registrations: value)
        }
        .sorted(by: { $0.service < $1.service})
    }

    var accessLevel: AccessLevel {
        if registrations.contains(where: {$0.accessLevel == .public}) {
            return .public
        }
        return .internal
    }

    var enumName: String {
        let sanitizedType = TypeNamer.sanitizeType(type: service, keepGenerics: true)
        return "\(sanitizedType)_ResolutionKey"
    }

    // The if config condition wrapping the entire group
    var ifConfigCondition: ExprSyntax? {
        guard let firstCondition = registrations.first?.ifConfigCondition else {
            return nil
        }
        // Only wrap the entire group if all conditions within the group match
        let allMatch = registrations.allSatisfy { $0.ifConfigCondition?.description == firstCondition.description }
        return allMatch ? firstCondition : nil
    }

}
