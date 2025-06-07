# VibeMeter Test Suite Documentation

This document describes the testing patterns, organization, and best practices used in the VibeMeter test suite.

## Test Organization

The test suite is organized using Swift Testing's nested suite structure for better organization and discoverability.

### Suite Structure

```swift
@Suite("Component Name Tests", .tags(.unit, .fast))
struct ComponentNameTests {
    @Suite("Feature Area 1")
    struct Feature1 { ... }
    
    @Suite("Feature Area 2") 
    struct Feature2 { ... }
}
```

### Test Files

Tests are consolidated by component rather than split across multiple files:

- `ProgressColorTests.swift` - Contains Basic, EdgeCases, and WarningLevels suites
- `URLQueryItemsTests.swift` - Contains Basic, Advanced, and RealWorld suites
- `CurrencyConversionTests.swift` - Contains conversion logic tests
- `PerformanceBenchmarks.swift` - Performance tests for critical paths

## Test Tags

We use a comprehensive tagging system defined in `TestTags.swift`:

### Speed Categories
- `.fast` - Tests that execute in < 100ms
- `.slow` - Tests that take > 100ms

### Test Type Categories
- `.unit` - Pure unit tests with mocked dependencies
- `.integration` - Tests that integrate multiple components
- `.performance` - Performance benchmark tests

### Feature Area Categories
- `.currency` - Currency conversion and formatting tests
- `.provider` - Provider-specific tests
- `.authentication` - Authentication and token management tests
- `.ui` - UI component tests
- `.settings` - Settings and preferences tests
- `.notifications` - Notification system tests
- `.background` - Background processing tests

### Environment Requirements
- `.requiresNetwork` - Tests that need internet connectivity
- `.requiresKeychain` - Tests that interact with Keychain
- `.serialized` - Tests that must run sequentially

## Testing Patterns

### 1. Parameterized Tests

Use parameterized tests to reduce duplication:

```swift
struct TestCase: Sendable {
    let input: String
    let expected: String
    let description: String
}

static let testCases: [TestCase] = [
    TestCase(input: "hello", expected: "HELLO", description: "lowercase to uppercase"),
    TestCase(input: "WORLD", expected: "WORLD", description: "already uppercase")
]

@Test("String transformation", arguments: testCases)
func stringTransformation(testCase: TestCase) {
    let result = testCase.input.uppercased()
    #expect(result == testCase.expected)
}
```

### 2. Test Data Builders

Use builder patterns for complex test data (see `TestDataBuilders.swift`):

```swift
let session = ProviderSessionBuilder()
    .withTeam(id: 12345, name: "Test Team")
    .withEmail("test@example.com")
    .build()

let invoice = InvoiceBuilder()
    .withItem(cents: 5000, description: "API Usage")
    .withPricing(description: "Pro Plan", id: "pro")
    .forMonth(3, year: 2024)
    .build()
```

### 3. Test Helpers

Common test helpers are available in:

- `SwiftTestingHelpers+Expectations.swift` - Custom expectations for doubles, collections, dates
- `SwiftTestingHelpers+Async.swift` - Async test utilities and mock verification helpers
- `TestFixtures.swift` - Reusable test data and constants

### 4. Mock Verification

Use helper methods for cleaner mock verification:

```swift
// Instead of multiple #expect calls
notificationManager.verifyWarningNotification(
    spending: 75.0,
    limit: 100.0,
    currency: "USD"
)
```

### 5. Async Testing

For async operations, use the provided helpers:

```swift
// Test with timeout
let result = try await AsyncTestHelper.testWithTimeout(timeout: 5.0) {
    try await someAsyncOperation()
}

// Mock URL session setup
mockURLSession.configureSuccess(
    data: jsonData,
    statusCode: 200,
    headers: ["Content-Type": "application/json"]
)
```

## Best Practices

### 1. Test Naming

- Use descriptive test names that explain what is being tested
- Include the condition and expected outcome
- Use @Test display names for clarity

```swift
@Test("Currency conversion with nil rate returns original amount")
func currencyConversionNilRate() { ... }
```

### 2. Test Independence

- Each test should be independent and not rely on other tests
- Use init() for setup instead of shared state
- Clean up in deinit if needed

### 3. Serialization

Tests that modify shared resources should use `.serialized`:

```swift
@Suite("UserDefaults Tests", .tags(.settings), .serialized)
struct UserDefaultsTests { ... }
```

### 4. Performance Testing

Add `.timeLimit` traits to performance-sensitive tests:

```swift
@Test("Large data processing", .timeLimit(.minutes(1)))
func largeDataProcessing() { ... }
```

### 5. Known Issues

Use `withKnownIssue` for flaky or temporarily failing tests:

```swift
withKnownIssue("Flaky on CI - Issue #123") {
    #expect(result == expected)
}
```

## Running Tests

### Command Line

```bash
# Run all tests
xcodebuild -workspace VibeMeter.xcworkspace -scheme VibeMeter test

# Run specific test suite
swift test --filter "CurrencyConversionTests"

# Run tests by tag
swift test --filter-tag fast
swift test --filter-tag currency

# Exclude tags
swift test --skip-tag slow
```

### Xcode

- Use Test Navigator to run individual tests or suites
- Filter tests by tag using the test plan
- Use parallel execution for faster test runs

## Test Coverage

Focus test coverage on:

1. **Business Logic** - Currency conversion, spending calculations
2. **State Management** - Provider sessions, connection status
3. **Error Handling** - Network errors, edge cases
4. **UI Logic** - Progress colors, formatting
5. **Integration Points** - API clients, data persistence

## Adding New Tests

When adding new tests:

1. Check if the test fits into an existing suite
2. Use appropriate tags for categorization
3. Consider using parameterized tests for multiple cases
4. Add test data to TestFixtures if reusable
5. Use builder patterns for complex test objects
6. Document any special requirements

## Continuous Integration

Tests are run on CI with:

- macOS 14.5+ required for Swift Testing
- Parallel execution enabled
- Fast tests run on every PR
- Full test suite runs on main branch
- Performance tests run nightly