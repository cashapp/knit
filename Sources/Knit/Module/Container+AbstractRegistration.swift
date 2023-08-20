//
// Copyright © Block, Inc. All rights reserved.
//

import Foundation

extension Container {

    /// Register that a service is expected to exist but no implementation is currently available
    /// The concrete implementation must be registered or the dependency graph is considered invalid
    public func registerAbstract<Service>(
        _ serviceType: Service.Type,
        name: String? = nil,
        file: StaticString = #file
    ) {
        // Simplify the name to support Xcode 14.2.
        // Once 14.2 support is dropped and #file becomes shortened this can be removed
        let shortFile = URL(fileURLWithPath: file.description).lastPathComponent
        let registration = RegistrationKey(serviceType: serviceType, name: name, file: shortFile)
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

// MARK: - Inner types

extension Container {

    struct AbstractRegistrationError: LocalizedError {
        let serviceType: String
        let file: String
        let name: String?

        var errorDescription: String? {
            var string = "Unsatisfied abstract registration. Service: \(serviceType), File: \(file)"
            if let name = name {
                string += ", Name: \(name)"
            }
            return string
        }
    }

    // Collect
    struct AbstractRegistrationErrors: LocalizedError {
        let errors: [AbstractRegistrationError]

        var errorDescription: String? {
            return errors.map { $0.localizedDescription }.joined(separator: "\n")
        }
    }

    fileprivate struct RegistrationKey: Hashable {
        let serviceType: Any.Type
        let name: String?
        // Source file used for debugging. Not included in hash calculation or equality
        let file: String

        public func hash(into hasher: inout Hasher) {
            ObjectIdentifier(serviceType).hash(into: &hasher)
            name?.hash(into: &hasher)
        }

        static func == (lhs: RegistrationKey, rhs: RegistrationKey) -> Bool {
            return lhs.serviceType == rhs.serviceType
                && lhs.name == rhs.name
        }
    }

    final class AbstractRegistrationContainer: Behavior {

        fileprivate var concreteRegistrations: Set<RegistrationKey> = []
        fileprivate var abstractRegistrations: [RegistrationKey] = []

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
            concreteRegistrations.insert(.init(serviceType: type, name: name, file: ""))
        }

        // Throws an error if any abstract registrations have not been implemented
        func validate() throws {
            let remainingAbstract = abstractRegistrations.filter { !concreteRegistrations.contains($0) }
            guard !remainingAbstract.isEmpty else { return }
            let errors = remainingAbstract.map {
                return AbstractRegistrationError(
                    serviceType: "\($0.serviceType)",
                    file: $0.file,
                    name: $0.name
                )
            }
            throw AbstractRegistrationErrors(errors: errors)
        }

    }

}
