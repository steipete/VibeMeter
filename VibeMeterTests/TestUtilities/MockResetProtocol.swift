import Foundation

/// Protocol for test mocks that provides standardized reset functionality.
///
/// This protocol eliminates duplication in test mock reset methods by providing
/// a consistent interface and default implementations for common reset patterns.
@MainActor
protocol MockResetProtocol: AnyObject {
    /// Resets all mock state to initial values.
    func reset()
    
    /// Resets all tracking properties (call counts, captured parameters).
    func resetTracking()
    
    /// Resets all return values to defaults.
    func resetReturnValues()
}

/// Default implementation helper for common mock properties.
@MainActor
extension MockResetProtocol {
    /// Helper to reset a call count property.
    func resetCallCount(_ keyPath: ReferenceWritableKeyPath<Self, Int>) {
        self[keyPath: keyPath] = 0
    }
    
    /// Helper to reset an optional captured parameter.
    func resetCapturedParameter<T>(_ keyPath: ReferenceWritableKeyPath<Self, T?>) {
        self[keyPath: keyPath] = nil
    }
    
    /// Helper to reset a captured parameters array.
    func resetCapturedArray<T>(_ keyPath: ReferenceWritableKeyPath<Self, [T]>) {
        self[keyPath: keyPath] = []
    }
    
    /// Helper to reset a boolean flag.
    func resetFlag(_ keyPath: ReferenceWritableKeyPath<Self, Bool>, to defaultValue: Bool = false) {
        self[keyPath: keyPath] = defaultValue
    }
}

/// Base class for mocks that provides common reset functionality.
@MainActor
class BaseMock: MockResetProtocol {
    /// Dictionary to store call counts by method name.
    private var callCounts: [String: Int] = [:]
    
    /// Dictionary to store captured parameters by method name.
    private var capturedParameters: [String: Any] = [:]
    
    /// Increments the call count for a method.
    func recordCall(_ methodName: String) {
        callCounts[methodName, default: 0] += 1
    }
    
    /// Gets the call count for a method.
    func callCount(for methodName: String) -> Int {
        callCounts[methodName, default: 0]
    }
    
    /// Captures a parameter for a method.
    func captureParameter<T>(_ parameter: T, for methodName: String) {
        capturedParameters[methodName] = parameter
    }
    
    /// Gets a captured parameter for a method.
    func capturedParameter<T>(for methodName: String, as type: T.Type) -> T? {
        capturedParameters[methodName] as? T
    }
    
    /// Resets all tracking data.
    func resetTracking() {
        callCounts.removeAll()
        capturedParameters.removeAll()
    }
    
    /// Default reset implementation.
    func reset() {
        resetTracking()
        resetReturnValues()
    }
    
    /// Override in subclasses to reset return values.
    func resetReturnValues() {
        // Subclasses should override this
    }
}