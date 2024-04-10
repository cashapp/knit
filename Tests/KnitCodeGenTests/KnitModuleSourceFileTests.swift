//
// Copyright © Block, Inc. All rights reserved.
//

@testable import KnitCodeGen
import XCTest

final class KnitModuleSourceFileTests: XCTestCase {

    func test_generation() throws {
        let configurations: [Configuration] = [
            .init(
                assemblyName: "MyAssembly",
                moduleName: "MyModule",
                registrations: [],
                registrationsIntoCollections: [],
                targetResolver: "AppResolver"
            ),
            .init(
                assemblyName: "SecondAssembly",
                moduleName: "MyModule",
                registrations: [],
                registrationsIntoCollections: [],
                targetResolver: "SignedInResolver"
            ),
        ]

        let result = try XCTUnwrap(KnitModuleSourceFile.make(configurations: configurations))

        let expected = #"""
        // Generated using Knit
        // Do not edit directly!

        import Knit
        public enum MyModule_KnitModule: KnitModule {
            public static var assemblies: [any ModuleAssembly.Type] {
                [
                    MyAssembly.self,
                    SecondAssembly.self]
            }
        }
        """#

        XCTAssertEqual(
            result.formatted().description,
            expected
        )
    }
}
