// Copyright © 2025 Zama. All rights reserved.

import Foundation

@propertyWrapper
struct UserDefaultsStorage<T> {
    let key: String
    let defaultValue: T
    private let defaults = UserDefaults.standard
    
    var wrappedValue: T {
        get {
            defaults.object(forKey: key) as? T ?? defaultValue
        }
        set {
            // Check whether we're dealing with an optional and remove the object if the new value is nil.
            if let optional = newValue as? AnyOptional, optional.isNil {
                defaults.removeObject(forKey: key)
            } else {
                defaults.set(newValue, forKey: key)
            }
        }
    }
}

/// Allows to match for optionals with generics that are defined as non-optional.
public protocol AnyOptional {
    /// Returns `true` if `nil`, otherwise `false`.
    var isNil: Bool { get }
}

extension Optional: AnyOptional {
    public var isNil: Bool { self == nil }
}
