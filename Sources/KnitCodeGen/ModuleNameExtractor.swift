//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation

/// Extracts the module name from an assembly file path based on regex pattern matching
struct ModuleNameExtractor {

    let moduleNameRegex: NSRegularExpression?

    init(moduleNamePattern: String?) throws {
        if let moduleNamePattern {
            let regex = try NSRegularExpression(pattern: moduleNamePattern)
            self.init(moduleNameRegex: regex)
        } else {
            self.init(moduleNameRegex: nil)
        }
    }

    init(moduleNameRegex: NSRegularExpression?) {
        self.moduleNameRegex = moduleNameRegex
    }

    func extractModuleName(path: String) -> String? {
        guard let moduleNameRegex else {
            return nil
        }
        guard let match = moduleNameRegex.firstMatch(in: path, range: NSRange(location: 0, length: path.count)) else {
            return nil
        }
        guard match.numberOfRanges == 2 else {
            return nil
        }
        return (path as NSString).substring(with: match.range(at: 1))
    }

}

