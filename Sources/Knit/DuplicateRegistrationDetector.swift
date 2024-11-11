//
// Copyright © Block, Inc. All rights reserved.
//

import Swinject

public final class DuplicateRegistrationDetector {

    /// If a duplicate registration is detected, the `Key` describing that registration will be provided to this closure.
    /// The closure can be called multiple times, once for each duplicate found.
    public var duplicateWasDetected: ((Key) -> Void)?

    /// An array of all the keys for duplicate registrations detected by this Behavior.
    /// The array is updated before the `duplicateWasDetected` closure is invoked so will always contain all detected duplicates up to that point.
    public private(set) var detectedKeys = [Key]()

    /// Describes a single registration key.
    /// If a duplicate is detected this key will be provided to the `duplicateWasDetected` closure.
    public struct Key {
        public let serviceType: Any.Type
        public let argumentsType: Any.Type
        public let name: String?
    }

    var existingRegistrations = Set<Key>()

    public init(
        duplicateWasDetected: ((Key) -> Void)? = nil
    ) {
        self.duplicateWasDetected = duplicateWasDetected
    }

}

// MARK: -

extension DuplicateRegistrationDetector: Behavior {

    public func container<Type, Service>(
        _ container: Container,
        didRegisterType type: Type.Type,
        toService entry: ServiceEntry<Service>,
        withName name: String?
    ) {
        // Make sure to use `didRegisterType type: Type.Type` rather than `Service`
        let key = Key(
            serviceType: type,
            argumentsType: entry.argumentsType,
            name: name
        )

        let preInsertCount = existingRegistrations.count
        existingRegistrations.insert(key)

        if preInsertCount == existingRegistrations.count {
            // The registration count did not increment, so the current service entry was a duplicate of an existing entry
            detectedKeys.append(key)
            duplicateWasDetected?(key)
        }
    }

}

// MARK: -

extension DuplicateRegistrationDetector.Key: Hashable, Equatable {

    public func hash(into hasher: inout Hasher) {
        ObjectIdentifier(serviceType).hash(into: &hasher)
        ObjectIdentifier(argumentsType).hash(into: &hasher)
        name?.hash(into: &hasher)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.serviceType == rhs.serviceType
            && lhs.argumentsType == rhs.argumentsType
            && lhs.name == rhs.name
    }

}

// MARK: -

extension DuplicateRegistrationDetector.Key: CustomStringConvertible {

    // Provide a more structured string description of the key, useful for logging error messages
    public var description: String {
        """
        Duplicate Registration Key
        Service type: \(serviceType)
        Arguments type: \(argumentsType)
        Name: \(name ?? "`nil`")
        """
    }
    

}

// MARK: -

extension Array where Element == DuplicateRegistrationDetector.Key {

    public var duplicatesDescription: String {
        guard count > 0 else {
            return "No duplicates in array"
        }

        let keyDescriptions = reduce("") { partialResult, key in
            partialResult + "\(key)\n\n"
        }
        return """
            Duplicate registrations were detected (count: \(count):
            \(keyDescriptions)
            """
    }

}
