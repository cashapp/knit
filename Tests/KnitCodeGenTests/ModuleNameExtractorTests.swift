//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
@testable import KnitCodeGen
import XCTest

final class ModuleNameExtractorTests: XCTestCase {

    func testWithoutCaptureGroup() throws {
        let extractor = try ModuleNameExtractor(moduleNamePattern: ".*")

        XCTAssertNil(extractor.extractModuleName(path: "Module/Assembly.swift"))
    }

    func testCaptureGroup() throws {
        let extractor = try ModuleNameExtractor(moduleNamePattern: "Code\\/(\\w+)/")
        XCTAssertEqual(
            extractor.extractModuleName(path: "Code/MyModule/"),
            "MyModule"
        )

        XCTAssertEqual(
            extractor.extractModuleName(path: "Code/MyModule/SomeFile.swift"),
            "MyModule"
        )

        XCTAssertNil(extractor.extractModuleName(path: "External/MyModule/Assembly.swift"))
    }

}
