//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation

extension Container {

    /// Register that a service is expected to exist but no implementation is currently available
    /// The concrete implementation must be registered or the dependency graph is considered invalid
    /// - NOTE: We don't currently support abstract registrations with arguments
    public func registerAbstract<Service>(
        _ serviceType: Service.Type,
        name: String? = nil,
        concurrency: ConcurrencyAttribute = .nonisolated,
        file: String = #fileID
    ) {
        let registration = RealAbstractRegistration<Service>(name: name, file: file, concurrency: concurrency)
        abstractRegistrations().abstractRegistrations.append(registration)
    }

    /// Register that a service is expected to exist but no implementation is currently available
    /// The concrete implementation must be registered or the dependency graph is considered invalid
    /// - NOTE: We don't currently support abstract registrations with arguments
    /// As this is an `Optional` Service type this allows special handling of the abstract registration for test environments:
    /// If during testing and no concrete registration is available, then `nil` will be resolved automatically.
    public func registerAbstract<Service>(
        _ serviceType: Optional<Service>.Type,
        name: String? = nil,
        concurrency: ConcurrencyAttribute = .nonisolated,
        file: String = #fileID
    ) {
        let registration = OptionalAbstractRegistration<Service>(name: name, file: file, concurrency: concurrency)
        abstractRegistrations().abstractRegistrations.append(registration)
    }

    // Must be called before using `registerAbstract`
    func registerAbstractContainer() -> AbstractRegistrationContainer {
        let registrations = AbstractRegistrationContainer()
        register(Container.AbstractRegistrationContainer.self, factory: { _ in registrations })
            .inObjectScope(.container)
        addBehavior(registrations)
        return registrations
    }

    private func abstractRegistrations() -> AbstractRegistrationContainer {
        return resolve(AbstractRegistrationContainer.self)!
    }
}

/// The information required to uniquely reference a Swinject registration
internal struct RegistrationKey: Hashable, Equatable {
    let typeIdentifier: ObjectIdentifier
    let name: String?
    let concurrency: ConcurrencyAttribute
}

/// Protocol version to allow storing generic types an array
internal protocol AbstractRegistration {
    associatedtype ServiceType

    var serviceDescription: String { get }
    var file: String { get }
    var name: String? { get }
    var key: RegistrationKey { get }
    var concurrency: ConcurrencyAttribute { get }

    /// Register a placeholder registration to fill the unfulfilled abstract registration
    /// This placeholder cannot be resolved
    func registerPlaceholder(
        container: Container,
        errorFormatter: ModuleAssemblerErrorFormatter,
        dependencyTree: DependencyTree
    )
}

extension AbstractRegistration {
    // Convert the key into an error
    var error: Container.AbstractRegistrationError {
        return Container.AbstractRegistrationError(
            serviceType: serviceDescription,
            file: file,
            name: name
        )
    }
}

// Implementation of AbstractRegistration
fileprivate struct RealAbstractRegistration<ServiceType>: AbstractRegistration {
    let name: String?
    // Source file used for debugging. Not included in hash calculation or equality
    let file: String

    var serviceDescription: String { String(describing: ServiceType.self) }

    let concurrency: ConcurrencyAttribute

    var key: RegistrationKey {
        return .init(
            typeIdentifier: ObjectIdentifier(ServiceType.self),
            name: name,
            concurrency: concurrency
        )
    }

    func registerPlaceholder(
        container: Container,
        errorFormatter: ModuleAssemblerErrorFormatter,
        dependencyTree: DependencyTree
    ) {
        let message = errorFormatter.format(error: self.error, dependencyTree: dependencyTree)
        container.register(ServiceType.self, name: name) { _ in
            fatalError("Attempt to resolve unfulfilled abstract registration.\n\(message)")
        }
    }
}

/// An abstract registration for an optional service
/// The `UnwrappedServiceType` represents the inner type of the Optional service type for the registration.
fileprivate struct OptionalAbstractRegistration<UnwrappedServiceType>: AbstractRegistration {
    let name: String?
    // Source file used for debugging. Not included in hash calculation or equality
    let file: String

    /// The actual service type added for this registration (includes the Optional wrapper).
    typealias ServiceType = Optional<UnwrappedServiceType>

    var serviceDescription: String { String(describing: ServiceType.self) }

    let concurrency: ConcurrencyAttribute

    var key: RegistrationKey {
        return .init(
            typeIdentifier: ObjectIdentifier(ServiceType.self),
            name: name,
            concurrency: concurrency
        )
    }

    func registerPlaceholder(
        container: Container,
        errorFormatter: ModuleAssemblerErrorFormatter,
        dependencyTree: DependencyTree
    ) {
        container.register(ServiceType.self, name: name) { _ in
            return nil
        }
    }
}

// MARK: - Inner types

extension Container {

    public struct AbstractRegistrationError: LocalizedError {
        public let serviceType: String
        public let file: String
        public let name: String?

        public var errorDescription: String? {
            var string = "Unsatisfied abstract registration. Service: \(serviceType), File: \(file)"
            if let name = name {
                string += ", Name: \(name)"
            }
            return string
        }
    }

    // Array of abstract registration errors
    public struct AbstractRegistrationErrors: LocalizedError {
        public let errors: [AbstractRegistrationError]

        public var errorDescription: String? {
            return errors.map { $0.localizedDescription }.joined(separator: "\n")
        }
    }

    final class AbstractRegistrationContainer: Behavior {

        fileprivate var concreteRegistrations: Set<RegistrationKey> = []
        fileprivate var abstractRegistrations: [any AbstractRegistration] = []

        func reset() {
            concreteRegistrations = []
            abstractRegistrations = []
        }

        func container<Type, Service>(
            _ container: Container,
            didRegisterType type: Type.Type,
            toService entry: ServiceEntry<Service>,
            withName name: String?
        ) {
            let id = RegistrationKey(
                typeIdentifier: ObjectIdentifier(Type.self),
                name: name,
                concurrency: .unknown
            )
            concreteRegistrations.insert(id)
        }

        var unfulfilledRegistrations: [any AbstractRegistration] {
            abstractRegistrations.filter { abstractRegistration in
                let abstractKey = abstractRegistration.key
                return !concreteRegistrations.contains { concreteKey in
                    // We need to ignore the concurrency attribute currently due to Swinject limitations
                    concreteKey.typeIdentifier == abstractKey.typeIdentifier &&
                        concreteKey.name == abstractKey.name
                }
            }
        }

        // Throws an error if any abstract registrations have not been implemented
        func validate() throws {
            let remainingAbstract = unfulfilledRegistrations
            guard !remainingAbstract.isEmpty else { return }
            let errors = remainingAbstract.map { $0.error }
            throw AbstractRegistrationErrors(errors: errors)
        }

    }

}
