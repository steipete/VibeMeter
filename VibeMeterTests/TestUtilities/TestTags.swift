import Testing

// MARK: - Test Tags Definition
// Tags are used to categorize and filter tests

extension Tag {
    // MARK: - Test Speed Categories
    
    /// Tests that execute quickly (< 100ms)
    @Tag static var fast: Self
    
    /// Tests that take longer to execute (> 100ms)
    @Tag static var slow: Self
    
    // MARK: - Test Type Categories
    
    /// Pure unit tests with mocked dependencies
    @Tag static var unit: Self
    
    /// Tests that integrate multiple components
    @Tag static var integration: Self
    
    /// Tests that make actual network calls
    @Tag static var network: Self
    
    // MARK: - Feature Area Categories
    
    /// Currency conversion and formatting tests
    @Tag static var currency: Self
    
    /// Provider-specific tests (Cursor, etc.)
    @Tag static var provider: Self
    
    /// Authentication and token management tests
    @Tag static var authentication: Self
    
    /// UI component and view tests
    @Tag static var ui: Self
    
    /// Settings and preferences tests
    @Tag static var settings: Self
    
    /// Notification system tests
    @Tag static var notifications: Self
    
    /// Background processing tests
    @Tag static var background: Self
    
    // MARK: - Environment Requirements
    
    /// Tests that require internet connectivity
    @Tag static var requiresNetwork: Self
    
    /// Tests that interact with Keychain
    @Tag static var requiresKeychain: Self
    
    /// Tests that require specific OS features
    @Tag static var requiresOS: Self
    
    // MARK: - Test Priority
    
    /// Critical tests that must always pass
    @Tag static var critical: Self
    
    /// Tests for edge cases and error conditions
    @Tag static var edgeCase: Self
    
    /// Performance-related tests
    @Tag static var performance: Self
}