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

private class ParentResolver: BaseResolver {}
private class ChildResolver: ParentResolver {
    public override class func inherits(from resolverType: Resolver.Type) -> Bool {
        return resolverType == self || resolverType == ParentResolver.self
    }
}
private class OtherResolver: BaseResolver {}

private struct Assembly1: GeneratedModuleAssembly {
    typealias TargetResolver = ParentResolver
    static var generatedDependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container<Self.TargetResolver>) {}
}

private struct Assembly2: GeneratedModuleAssembly {
    typealias TargetResolver = ChildResolver
    static var generatedDependencies: [any ModuleAssembly.Type] { [Assembly1.self] }
    func assemble(container: Container<Self.TargetResolver>) {}
}

private struct Assembly3: GeneratedModuleAssembly {
    typealias TargetResolver = OtherResolver
    static var generatedDependencies: [any ModuleAssembly.Type] { [Assembly2.self, Assembly1.self] }
    func assemble(container: Container<Self.TargetResolver>) {}
}

private struct Assembly4: GeneratedModuleAssembly {
    typealias TargetResolver = ParentResolver
    static var generatedDependencies: [any ModuleAssembly.Type] { [Assembly1.self] }
    func assemble(container: Container<Self.TargetResolver>) {}
}
