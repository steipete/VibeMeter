import Testing

// MARK: - Test Tags Definition

/// Tags are used to categorize and filter tests. They enable:
/// - Running specific subsets of tests (e.g., only fast unit tests)
/// - Skipping flaky tests in CI
/// - Organizing tests by feature area
/// - Creating test plans for different scenarios
///
/// Usage in tests:
/// ```swift
/// @Test("Example test", .tags(.fast, .unit))
/// func exampleTest() { }
/// ```
///
/// Running tests by tag:
/// ```bash
/// swift test --filter .fast --filter .unit  # Run fast unit tests
/// swift test --skip .flaky                  # Skip flaky tests
/// swift test --filter .critical --filter .smoke  # Run critical smoke tests
/// ```

extension Tag {
    // MARK: - Test Speed Categories

    /// Tests that execute quickly (< 100ms)
    @Tag
    static var fast: Self

    /// Tests that take longer to execute (> 100ms)
    @Tag
    static var slow: Self

    // MARK: - Test Type Categories

    /// Pure unit tests with mocked dependencies
    @Tag
    static var unit: Self

    /// Tests that integrate multiple components
    @Tag
    static var integration: Self

    /// Tests that make actual network calls
    @Tag
    static var network: Self

    // MARK: - Feature Area Categories

    /// Currency conversion and formatting tests
    @Tag
    static var currency: Self

    /// Provider-specific tests (Cursor, etc.)
    @Tag
    static var provider: Self

    /// Authentication and token management tests
    @Tag
    static var authentication: Self

    /// UI component and view tests
    @Tag
    static var ui: Self

    /// Settings and preferences tests
    @Tag
    static var settings: Self

    /// Notification system tests
    @Tag
    static var notifications: Self

    /// Background processing tests
    @Tag
    static var background: Self

    // MARK: - Environment Requirements

    /// Tests that require internet connectivity
    @Tag
    static var requiresNetwork: Self

    /// Tests that interact with Keychain
    @Tag
    static var requiresKeychain: Self

    /// Tests that require specific OS features
    @Tag
    static var requiresOS: Self

    // MARK: - Test Priority

    /// Critical tests that must always pass
    @Tag
    static var critical: Self

    /// Tests for edge cases and error conditions
    @Tag
    static var edgeCase: Self

    /// Performance-related tests
    @Tag
    static var performance: Self

    /// Memory management and retention tests
    @Tag
    static var memory: Self

    /// Concurrent execution tests
    @Tag
    static var concurrent: Self

    // MARK: - Test Stability

    /// Tests that may fail intermittently due to timing or external factors
    @Tag
    static var flaky: Self

    /// Regression tests for previously fixed bugs
    @Tag
    static var regression: Self

    /// Smoke tests for basic functionality
    @Tag
    static var smoke: Self

    /// Tests with known issues (using withKnownIssue)
    @Tag
    static var knownIssue: Self

    /// Experimental features under development
    @Tag
    static var experimental: Self

    // MARK: - Platform Specific

    /// Tests specific to macOS platform features
    @Tag
    static var macOS: Self

    /// Tests that require specific hardware features
    @Tag
    static var hardware: Self
}
