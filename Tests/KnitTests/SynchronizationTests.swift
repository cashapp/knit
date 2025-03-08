//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation
@testable import Knit
import XCTest

final class SynchronizationTests: XCTestCase {

    @MainActor
    func testMultiThreadResolving() async throws {
        // Use a parent/child relationship to test synchronization between containers
        let parent = ModuleAssembler([Assembly1()])
        let assembler = ModuleAssembler(parent: parent, [Assembly2()])

        // Resolve the same service in 2 separate tasks
        async let task1 = try Task {
            return assembler.resolver.resolve(Service2.self)!
        }.result.get()

        async let task2 = try Task {
            return assembler.resolver.resolve(Service2.self)!
        }.result.get()

        let result = try await (task1, task2)

        // Make sure that the weak services correctly return the same value
        XCTAssertEqual(result.0.service1.id, result.1.service1.id)
    }

    @MainActor
    func testMultiThreadingScopedAssembler() async throws {
        let assembler = ScopedModuleAssembler<TestScopedResolver>([Assembly2()])

        // Resolve the same service in 2 separate tasks
        async let task1 = try Task {
            return assembler.resolver.resolve(Service2.self)!
        }.result.get()

        async let task2 = try Task {
            return assembler.resolver.resolve(Service2.self)!
        }.result.get()

        let result = try await (task1, task2)

        // Make sure that the weak services correctly return the same value
        XCTAssertEqual(result.0.service1.id, result.1.service1.id)
    }

}

private struct Assembly1: AutoInitModuleAssembly {
    typealias TargetResolver = TestScopedResolver
    static var dependencies: [any ModuleAssembly.Type] { [] }
    func assemble(container: Container) {
        container.register(Service1.self) { _ in Service1() }
    }
}

private struct Assembly2: ModuleAssembly {
    typealias TargetResolver = TestScopedResolver
    static var dependencies: [any ModuleAssembly.Type] { [Assembly1.self] }
    func assemble(container: Container) {
        container.register(Service2.self) { Service2(service1: $0.resolve(Service1.self)! )}
            .inObjectScope(.weak)
    }
}

private final class Service1 {
    let id: String = UUID().uuidString
}

private final class Service2 {
    let service1: Service1

    init(service1: Service1) {
        self.service1 = service1
    }
}

public protocol TestScopedResolver: Resolver { }
extension Container: TestScopedResolver {}
