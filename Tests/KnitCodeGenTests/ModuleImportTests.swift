//
// Copyright © Block, Inc. All rights reserved.
//

@testable import KnitCodeGen
import XCTest

final class ModuleImportTests: XCTestCase {

    func testNamedImport() {
        let imp = ModuleImport.named("Test")
        XCTAssertEqual(imp.description, "import Test")
    }

    func testTestableImport() {
        let imp = ModuleImport.testable(name: "Test")
        XCTAssertEqual(imp.description, "@testable import Test")
    }

    func testImportContainerInit() {
        let container = ModuleImportSet(imports: [
            .named("Test1"),
            .named("Test2"),
            .named("Test1"),
            .testable(name: "Test2")
        ])

        XCTAssertEqual(container.sorted.count, 2)
        XCTAssertEqual(
            container.sorted.map { $0.description },
            [
                "import Test1",
                "@testable import Test2"
            ]
        )
    }

    func testImportContainerInsert() {
        var container = ModuleImportSet(imports: [])
        container.insert(.named("MyModule"))
        XCTAssertEqual(
            container.sorted.map { $0.description },
            [
                "import MyModule",
            ]
        )
        container.insert(.named("MyModule"))
        XCTAssertEqual(container.sorted.count, 1)

        container.insert(.named("MyModule2"))
        XCTAssertEqual(container.sorted.count, 2)

        container.insert(.testable(name: "AModule"))
        container.insert(.named("AModule"))
        XCTAssertEqual(container.sorted.count, 3)

        XCTAssertEqual(
            container.sorted.map { $0.description },
            [
                "@testable import AModule",
                "import MyModule",
                "import MyModule2",
            ]
        )
    }
}
