//
// Copyright © Block, Inc. All rights reserved.
//

@testable import Knit
import XCTest

final class ModuleAssemblyScopingTests: XCTestCase {

    func test_identicalScopes() {
        XCTAssertEqual(Assembly4.dependencies.count, 1)
        XCTAssertTrue(Assembly4.dependencies.first == Assembly1.self)
    }

    func test_compatibleScopes() {
        XCTAssertEqual(Assembly2.dependencies.count, 1)
        XCTAssertTrue(Assembly2.dependencies.first == Assembly1.self)
    }

    func test_incompatibleScopes() {
        XCTAssertEqual(Assembly3.dependencies.count, 0)
    }

}

private protocol ParentResolver: Resolver {}
private protocol ChildResolver: Resolver {}
private protocol OtherResolver: Resolver {}

extension ChildResolver {
    static func contains(resolver: Resolver.Type) -> Bool {
        return resolver == self || resolver == ParentResolver.self
    }
}

private struct Assembly1: GeneratedModuleAssembly {
    typealias TargetResolver = ParentResolver
    static var generatedDependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) {}
}

private struct Assembly2: GeneratedModuleAssembly {
    typealias TargetResolver = ChildResolver
    static var generatedDependencies: [any ModuleAssembly.Type] { [Assembly1.self] }
    func assemble(container: Container) {}
}

private struct Assembly3: GeneratedModuleAssembly {
    typealias TargetResolver = OtherResolver
    static var generatedDependencies: [any ModuleAssembly.Type] { [Assembly2.self, Assembly1.self] }
    func assemble(container: Container) {}
}

private struct Assembly4: GeneratedModuleAssembly {
    typealias TargetResolver = ParentResolver
    static var generatedDependencies: [any ModuleAssembly.Type] { [Assembly1.self] }
    func assemble(container: Container) {}
}

private extension ModuleAssembly {
    // Override the default scoping function to allow assemblies using ParentResolver to be included in ChildResolver
    static func scoped(_ dependencies: [any ModuleAssembly.Type]) -> [any ModuleAssembly.Type] {
        return dependencies.filter {
            if self.resolverType == ChildResolver.self && $0.resolverType == ParentResolver.self {
                return true
            }
            return self.resolverType == $0.resolverType
        }
    }
}
