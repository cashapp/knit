//
//  SourceFileSyntax+Write.swift
//  
//
//  Created by Brad Fol on 8/4/23.
//

import Foundation
import SwiftSyntax

public extension SourceFileSyntax {

    /// Encode the receiver to UTF8 text and write to the provided path.
    func write(to path: String) {
        let data = self.formatted().description.data(using: .utf8)!

        let pathURL = URL(fileURLWithPath: path, isDirectory: false)

        do {
            try data.write(to: pathURL)
        } catch {
            fatalError("\(error)")
        }
    }

}
