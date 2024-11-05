//
// Copyright © Block, Inc. All rights reserved.
//

/// Represents a single concrete factory registered into a collection
/// A separate instance will be created for each call to `{auto}registerIntoCollection`
public struct RegistrationIntoCollection: Equatable, Sendable {

    public var service: String

    public init(service: String) {
        self.service = service
    }

}
