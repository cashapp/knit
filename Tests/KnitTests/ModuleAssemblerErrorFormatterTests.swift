//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import XCTest

final class ModuleAssemblerErrorFormatterTests: XCTestCase {

    func testScopedErrorConversion() {
        let formatter = TestErrorFormatter()
        let message = formatter.format(
            error: ScopedModuleAssemblerError.incorrectTargetResolver(expected: "A", actual: "B"),
            dependencyTree: nil
        )
        XCTAssertEqual(message, "Scoped")
    }
}

private final class TestErrorFormatter: ModuleAssemblerErrorFormatter {

    func format(knitError: KnitAssemblyError, dependencyTree: DependencyTree?) -> String {
        switch knitError {
        case .dependencyBuilder:
            return "Dependency Builder"
        case .scoped:
            return "Scoped"
        case .abstract:
            return "Abstract"
        case .abstractList:
            return "Abstract List"
        }
    }

}
