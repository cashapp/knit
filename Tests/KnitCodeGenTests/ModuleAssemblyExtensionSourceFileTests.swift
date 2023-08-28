//
//  ModuleAssemblyExtensionSourceFileTests.swift
//  
//
//  Created by Brad Fol on 8/7/23.
//

@testable import KnitCodeGen
import XCTest

final class ModuleAssemblyExtensionSourceFileTests: XCTestCase {

    func test_generation() {
        let result = ModuleAssemblyExtensionSourceFile.make(
            currentModuleName: "CurrentModule",
            dependencyModuleNames: [
                "DependencyA",
                "DependencyB",
            ],
            additionalAssemblies: []
        )

        let expected = #"""

        // Generated using Knit
        // Do not edit directly!

        import Knit
        import DependencyA
        import DependencyB
        extension CurrentModuleAssembly: GeneratedModuleAssembly {
            public static var generatedDependencies: [any ModuleAssembly.Type] {
                [
                DependencyAAssembly.self,
                DependencyBAssembly.self]
            }
        }
        """#

        XCTAssertEqual(
            result.formatted().description.replacingOccurrences(of: ", \n", with: ",\n"),
            expected
        )
    }

    func test_generation_emptyDependencies() {
        let result = ModuleAssemblyExtensionSourceFile.make(
            currentModuleName: "CurrentModule",
            dependencyModuleNames: [
            ],
            additionalAssemblies: []
        )

        let expected = #"""

        // Generated using Knit
        // Do not edit directly!

        import Knit
        extension CurrentModuleAssembly: GeneratedModuleAssembly {
            public static var generatedDependencies: [any ModuleAssembly.Type] {
                []
            }
        }
        """#

        XCTAssertEqual(
            result.formatted().description.replacingOccurrences(of: ", \n", with: ",\n"),
            expected
        )
    }

    func test_generation_additionalAssemblies() {
        let result = ModuleAssemblyExtensionSourceFile.make(
            currentModuleName: "CurrentModule",
            dependencyModuleNames: [
                "DependencyA",
                "DependencyASubAssembly",
            ],
            additionalAssemblies: [
                "DependencyAOtherAssembly",
            ]
        )

        let expected = #"""

        // Generated using Knit
        // Do not edit directly!

        import Knit
        import DependencyA
        extension CurrentModuleAssembly: GeneratedModuleAssembly {
            public static var generatedDependencies: [any ModuleAssembly.Type] {
                [
                DependencyAAssembly.self,
                DependencyASubAssembly.self,
                DependencyAOtherAssembly.self]
            }
        }
        """#

        XCTAssertEqual(
            result.formatted().description.replacingOccurrences(of: ", \n", with: ",\n"),
            expected
        )
    }

}
