import Foundation

/// Property wrapper for UserDefaults-backed properties
@propertyWrapper
struct UserDefaultsBacked<T> {
    let key: String
    let defaultValue: T
    let userDefaults: UserDefaults

    init(key: String, defaultValue: T, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }

    var wrappedValue: T {
        get {
            userDefaults.object(forKey: key) as? T ?? defaultValue
        }
        set {
            if let optionalValue = newValue as? any OptionalProtocol, optionalValue.isNil {
                userDefaults.removeObject(forKey: key)
            } else {
                userDefaults.set(newValue, forKey: key)
            }
        }
    }
}

// Helper protocol to check if optional is nil
private protocol OptionalProtocol {
    var isNil: Bool { get }
}

extension Optional: OptionalProtocol {
    var isNil: Bool { self == nil }
}
