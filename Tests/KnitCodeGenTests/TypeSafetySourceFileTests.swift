//
// Copyright © Block, Inc. All rights reserved.
//

@testable import KnitCodeGen
import Foundation
import SwiftSyntax
import XCTest

final class TypeSafetySourceFileTests: XCTestCase {

    func test_generation() throws {
        let result = try TypeSafetySourceFile.make(
            from: Configuration(
                assemblyName: "ModuleAssembly",
                moduleName: "Module",
                registrations: [
                    .init(service: "ServiceA", name: nil),
                    .init(service: "ServiceB", name: "name"),
                    .init(service: "ServiceB", name: "otherName"),
                    .init(service: "ServiceC", name: nil, accessLevel: .hidden), // No resolver is created
                    .init(service: "ServiceD", name: nil, accessLevel: .public, getterAlias: "serviceDAlias", functionName: .implements),
                    .init(service: "ServiceE", name: nil, accessLevel: .public, arguments: [
                        .init(type: "@escaping () -> Void"),
                        .init(type: "@escaping @Sendable (Bool) -> Void")
                    ]),
                    .init(service: "ServiceF", name: nil, accessLevel: .public),
                    .init(service: "(String, Int?)", name: nil, accessLevel: .public),
                ],
                targetResolver: "Resolve"
            )
        )

        let expected = """
        /// Generated from ``ModuleAssembly``
        extension Resolve {
            func serviceA(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> ServiceA {
                knitUnwrap(unsafeResolver.resolve(ServiceA.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            public func serviceD(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> ServiceD {
                knitUnwrap(unsafeResolver.resolve(ServiceD.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            public func serviceDAlias(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> ServiceD {
                knitUnwrap(unsafeResolver.resolve(ServiceD.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            public func serviceE(closure1: @escaping () -> Void, closure2: @escaping @Sendable (Bool) -> Void, file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> ServiceE {
                knitUnwrap(unsafeResolver.resolve(ServiceE.self, arguments: closure1, closure2), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            public func serviceF(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> ServiceF {
                knitUnwrap(unsafeResolver.resolve(ServiceF.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            public func stringInt(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> (String, Int?) {
                knitUnwrap(unsafeResolver.resolve((String, Int?).self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            func serviceB(name: ModuleAssembly.ServiceB_ResolutionKey, file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> ServiceB {
                knitUnwrap(unsafeResolver.resolve(ServiceB.self, name: name.rawValue), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
        }
        extension ModuleAssembly {
            enum ServiceB_ResolutionKey: String, CaseIterable {
                case name
                case otherName
            }
        }
        extension ModuleAssembly {
            public static var _assemblyFlags: [ModuleAssemblyFlags] {
                []
            }
            public static func _autoInstantiate() -> (any ModuleAssembly)? {
                nil
            }
        }
        """

        XCTAssertEqual(expected, result.formatted().description)
    }

    func testRegistrationMultipleArguments() {
        let registration = Registration(service: "A", accessLevel: .public, arguments: [.init(type: "String"), .init(type: "URL")])
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolverString(
                registration: registration,
                enumName: nil
            ),
            """
            public func a(string: String, url: URL, file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> A {
                knitUnwrap(unsafeResolver.resolve(A.self, arguments: string, url), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            """
        )
    }

    func testRegistrationSingleArgument() {
        let registration = Registration(service: "A", accessLevel: .public, arguments: [.init(type: "String")])
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolverString(
                registration: registration,
                enumName: nil
            ),
            """
            public func a(string: String, file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> A {
                knitUnwrap(unsafeResolver.resolve(A.self, argument: string), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            """
        )
    }

    func testRegistrationDuplicateParamType() {
        let registration = Registration(service: "A", accessLevel: .public, arguments: [.init(type: "String"), .init(type: "String")])
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolverString(
                registration: registration,
                enumName: nil
            ),
            """
            public func a(string1: String, string2: String, file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> A {
                knitUnwrap(unsafeResolver.resolve(A.self, arguments: string1, string2), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            """
        )
    }

    func testRegistrationArgumentAndName() {
        let registration = Registration(service: "A", name: "test", accessLevel: .public, arguments: [.init(type: "String")])
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolverString(
                registration: registration,
                enumName: "MyAssembly.A_ResolutionKey"
            ),
            """
            public func a(name: MyAssembly.A_ResolutionKey, string: String, file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> A {
                knitUnwrap(unsafeResolver.resolve(A.self, name: name.rawValue, argument: string), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            """
        )
    }

    func testRegistrationWithPrenamedArguments() {
        let registration = Registration(service: "A", accessLevel: .public, arguments: [.init(identifier: "arg", type: "String")])
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolverString(
                registration: registration,
                enumName: nil
            ),
            """
            public func a(arg: String, file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> A {
                knitUnwrap(unsafeResolver.resolve(A.self, argument: arg), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            """
        )
    }

    func testRegistrationWithIfConfig() {
        var registration = Registration(service: "A", accessLevel: .public)
        registration.ifConfigCondition = ExprSyntax("SOME_FLAG")
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolverString(
                registration: registration,
                enumName: nil
            ),
            """
            #if SOME_FLAG
            public func a(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> A {
                knitUnwrap(unsafeResolver.resolve(A.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            #endif
            """
        )
    }

    func testRegistrationWithIfConfigAndAlias() {
        var registration = Registration(service: "A", accessLevel: .public, getterAlias: "fooAlias")
        registration.ifConfigCondition = ExprSyntax("SOME_FLAG")
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolverString(
                registration: registration,
                enumName: nil
            ),
            """
            #if SOME_FLAG
            public func a(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> A {
                knitUnwrap(unsafeResolver.resolve(A.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            public func fooAlias(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> A {
                knitUnwrap(unsafeResolver.resolve(A.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            #endif
            """
        )
    }

    func testRegistrationWithSPI() {
        let registration = Registration(service: "A", accessLevel: .public, spi: "Testing")
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolverString(
                registration: registration,
                enumName: nil
            ),
            """
            @_spi(Testing) public func a(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> A {
                knitUnwrap(unsafeResolver.resolve(A.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            """
        )
    }

    func testRegisrationWithGetterAlias() {
        let registration = Registration(service: "A", accessLevel: .public, getterAlias: "fooAlias")
        XCTAssertEqual(
            try TypeSafetySourceFile.makeResolverString(
                registration: registration
            ),
            """
            public func a(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> A {
                knitUnwrap(unsafeResolver.resolve(A.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            public func fooAlias(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> A {
                knitUnwrap(unsafeResolver.resolve(A.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
            """
        )
    }

    func testArgumentIdentifiers() {
        let registration1 = Registration(service: "A", arguments: [.init(type: "String?")])
        XCTAssertEqual(
            registration1.uniquelyIdentifiedArguments().map { $0.resolvedIdentifier() },
            ["string"]
        )

        let registration2 = Registration(service: "A", arguments: [.init(type: "Service.Argument")])
        XCTAssertEqual(
            registration2.uniquelyIdentifiedArguments().map { $0.resolvedIdentifier() },
            ["argument"]
        )

        let registration3 = Registration(service: "A", arguments: [.init(type: "Result<String, Error>")])
        XCTAssertEqual(
            registration3.uniquelyIdentifiedArguments().map { $0.resolvedIdentifier() },
            ["result"]
        )

        let registration4 = Registration(
            service: "A",
            arguments: [.init(type: "[Result<ServerResponse<Any>, Swift.Error>]")]
        )
        XCTAssertEqual(
            registration4.uniquelyIdentifiedArguments().map { $0.resolvedIdentifier() },
            ["result"]
        )

        // Argument identifier uniqueness
        let registration5 = Registration(
            service: "A",
            arguments: [
                // First integer
                .init(type: "Int"),
                // Only one instance of String, no uniqueness needed
                .init(type: "String"),
                // First closure
                .init(type: "@escaping () -> Void"),
                // Second integer
                .init(type: "Int"),
                // Second closure
                // Note the type is different to the first closure but the resolved identifier will be the same
                // (i.e. "closure") so uniqueness will need to be added to avoid collision.
                .init(type: "@escaping @MainActor (Bool) -> String"),
                // Third integer
                .init(type: "Int")
            ]
        )
        XCTAssertEqual(
            registration5.uniquelyIdentifiedArguments().map { $0.resolvedIdentifier() },
            [
                "int1",
                "string",
                "closure1",
                "int2",
                "closure2",
                "int3"
            ]
        )
    }

    func test_fakeAssembly_defaultOverride_generation() throws {
        let result = try TypeSafetySourceFile.make(
            from: Configuration(
                assemblyName: "MyFakeAssembly",
                moduleName: "Module",
                assemblyType: .fakeAssembly,
                registrations: [],
                replaces: ["RealAssembly"],
                targetResolver: "Resolver"
            )
        )

        let expected = """
        /// Generated from ``MyFakeAssembly``
        extension Resolver {
        }
        /// For assemblies that conform to `FakeAssembly`, Knit automatically generates
        /// default overrides for all other types it replaces.
        extension RealAssembly: Knit.DefaultModuleAssemblyOverride {
            public typealias OverrideType = MyFakeAssembly
        }
        extension MyFakeAssembly {
            public static var _assemblyFlags: [ModuleAssemblyFlags] {
                [.autoInit]
            }
            public static func _autoInstantiate() -> (any ModuleAssembly)? {
                MyFakeAssembly()
            }
        }
        """

        XCTAssertEqual(expected, result.formatted().description)
    }

    func test_fakeAssembly_defaultOverride_multipleGeneration() throws {
        let result = try TypeSafetySourceFile.make(
            from: Configuration(
                assemblyName: "MyFakeAssembly",
                moduleName: "Module",
                assemblyType: .fakeAssembly,
                registrations: [],
                replaces: [
                    "RealAssembly",
                    "OtherRealAssembly",
                ],
                targetResolver: "Resolver"
            )
        )

        let expected = """
        /// Generated from ``MyFakeAssembly``
        extension Resolver {
        }
        /// For assemblies that conform to `FakeAssembly`, Knit automatically generates
        /// default overrides for all other types it replaces.
        extension RealAssembly: Knit.DefaultModuleAssemblyOverride {
            public typealias OverrideType = MyFakeAssembly
        }
        extension OtherRealAssembly: Knit.DefaultModuleAssemblyOverride {
            public typealias OverrideType = MyFakeAssembly
        }
        extension MyFakeAssembly {
            public static var _assemblyFlags: [ModuleAssemblyFlags] {
                [.autoInit]
            }
            public static func _autoInstantiate() -> (any ModuleAssembly)? {
                MyFakeAssembly()
            }
        }
        """

        XCTAssertEqual(expected, result.formatted().description)
    }

    func test_abstract_generation() throws {
        let result = try TypeSafetySourceFile.make(
            from: Configuration(
                assemblyName: "SomeAbstractAssembly",
                moduleName: "Module",
                assemblyType: .abstractAssembly,
                registrations: [],
                replaces: [],
                targetResolver: "AccountResolver"
            )
        )

        let expected = """
        /// Generated from ``SomeAbstractAssembly``
        extension AccountResolver {
        }
        extension SomeAbstractAssembly {
            public static var _assemblyFlags: [ModuleAssemblyFlags] {
                [.autoInit, .abstract]
            }
            public static func _autoInstantiate() -> (any ModuleAssembly)? {
                SomeAbstractAssembly()
            }
        }
        """

        XCTAssertEqual(expected, result.formatted().description)
    }

    func test_mainActor_resolver() throws {
        let result = try TypeSafetySourceFile.make(
            from: Configuration(
                assemblyName: "MainActorAssembly",
                moduleName: "Module",
                registrations: [
                    .init(service: "ServiceA", concurrencyModifier: "@MainActor")
                ],
                targetResolver: "Resolver"
            )
        )
        let expected = """
        /// Generated from ``MainActorAssembly``
        extension Resolver {
            @MainActor func serviceA(file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) -> ServiceA {
                knitUnwrap(unsafeResolver.resolve(ServiceA.self), callsiteFile: file, callsiteFunction: function, callsiteLine: line)
            }
        }
        extension MainActorAssembly {
            public static var _assemblyFlags: [ModuleAssemblyFlags] {
                []
            }
            public static func _autoInstantiate() -> (any ModuleAssembly)? {
                nil
            }
        }
        """

        XCTAssertEqual(expected, result.formatted().description)
    }

}

private extension TypeSafetySourceFile {

    static func makeResolverString(
        registration: Registration,
        enumName: String? = nil
    ) throws -> String {
        try TypeSafetySourceFile.makeResolvers(
            registration: registration,
            enumName: enumName,
            getterAlias: registration.getterAlias
        )
        .map { $0.formatted().description }
        .joined(separator: "\n")
    }

}
