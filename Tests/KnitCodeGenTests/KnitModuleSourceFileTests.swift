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

        let result = try XCTUnwrap(
            KnitModuleSourceFile.make(
                configurations: configurations,
                dependencies: ["ModuleB", "ModuleC"]
            )
        )

        let expected = #"""
        public enum MyModule_KnitModule: KnitModule {
            public static var assemblies: [any ModuleAssembly.Type] {
                [
                    MyAssembly.self,
                    SecondAssembly.self]
            }
            public static var moduleDependencies: [KnitModule.Type] {
                [
                    ModuleB_KnitModule.self,
                    ModuleC_KnitModule.self]
            }
        }
        extension MyAssembly: GeneratedModuleAssembly {
            public static var generatedDependencies: [any ModuleAssembly.Type] {
                MyModule_KnitModule.allAssemblies
            }
        }
        extension SecondAssembly: GeneratedModuleAssembly {
            public static var generatedDependencies: [any ModuleAssembly.Type] {
                MyModule_KnitModule.allAssemblies
            }
        }
        """#

        XCTAssertEqual(
            result.formatted().description,
            expected
        )
    }
}
