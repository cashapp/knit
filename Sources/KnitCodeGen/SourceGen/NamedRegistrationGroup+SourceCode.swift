//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
import SwiftSyntax

extension NamedRegistrationGroup {
    // Generate the enum for this group of named registrations
    func enumSourceCode(assemblyName: String) throws -> DeclSyntaxProtocol {
        let modifier = accessLevel == .public ? "public " : ""
        let enumSyntax = try EnumDeclSyntax("\(raw: modifier)enum \(raw: enumName): String, CaseIterable") {
            for reg in registrations {
                ("case \(raw: reg.name!)" as DeclSyntax).maybeWithCondition(
                    ifConfigCondition: ifConfigCondition == nil ? reg.ifConfigCondition : nil
                )
            }
        }
        return enumSyntax.maybeWithCondition(ifConfigCondition: ifConfigCondition)
    }
}
