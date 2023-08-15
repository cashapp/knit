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
            ]
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
            ]
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

}
