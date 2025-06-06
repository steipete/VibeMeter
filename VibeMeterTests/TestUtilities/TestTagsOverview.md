# Test Tags Overview

This document provides an overview of how test tags are applied across the VibeMeter test suite.

## Tag Categories

### Speed Tags
- `.fast` - Tests that execute quickly (< 100ms)
- `.slow` - Tests that take longer to execute (> 100ms)

### Type Tags
- `.unit` - Pure unit tests with mocked dependencies
- `.integration` - Tests that integrate multiple components
- `.network` - Tests that make actual network calls

### Feature Area Tags
- `.currency` - Currency conversion and formatting tests
- `.provider` - Provider-specific tests (Cursor, etc.)
- `.authentication` - Authentication and token management tests
- `.ui` - UI component and view tests
- `.settings` - Settings and preferences tests
- `.notifications` - Notification system tests
- `.background` - Background processing tests

### Environment Tags
- `.requiresNetwork` - Tests that require internet connectivity
- `.requiresKeychain` - Tests that interact with Keychain
- `.requiresOS` - Tests that require specific OS features

### Priority Tags
- `.critical` - Critical tests that must always pass
- `.edgeCase` - Tests for edge cases and error conditions
- `.performance` - Performance-related tests

## Tagged Test Suites

### Authentication
- `AuthenticationTokenManagerCoreTests` - `.authentication, .unit, .fast`
- `AuthenticationTokenManagerEdgeCasesTests` - `.authentication, .edgeCase, .unit, .fast`

### Currency
- `CurrencyConversionBasicTests` - `.currency, .unit, .fast`
- `ExchangeRateManagerNetworkTests` - `.network, .integration, .slow`

### Providers
- `CursorProviderBasicTests` - `.provider, .unit, .fast`
- `CursorProviderDataTests` - `.provider, .integration, .network`

### UI/Menu Bar
- `MenuBarStateManagerTests` - `.ui, .unit, .fast`
- `MenuBarStateManagerAnimationTests` - `.ui, .unit, .performance`

### Notifications
- `NotificationManagerBasicTests` - `.notifications, .unit, .fast`
- `NotificationManagerContentTests` - `.notifications, .unit, .fast`

### Settings
- `SettingsManagerTests` - `.settings, .unit, .fast`

### Background Processing
- `BackgroundDataProcessorBasicTests` - `.background, .unit, .fast`
- `BackgroundDataProcessorErrorTests` - `.background, .edgeCase, .unit`

### Other Core Components
- `MultiProviderDataOrchestratorTests` - `.integration, .critical`
- `MultiProviderArchitectureTests` - `.integration, .unit`
- `NetworkRetryHandlerExecutionTests` - `.network, .unit`
- `SparkleUpdaterManagerTests` - `.unit, .fast`
- `StartupManagerTests` - `.unit, .fast`
- `KeychainHelperTests` - `.requiresKeychain, .unit`
- `LoggingServiceCoreTests` - `.unit, .fast`
- `GravatarServiceCoreTests` - `.network, .unit`

## Running Tests by Tag

Use the `test-by-tag.sh` script to run specific test categories:

```bash
# Run only fast unit tests
./scripts/test-by-tag.sh --tag fast --tag unit

# Run critical tests
./scripts/test-by-tag.sh --tag critical

# Run all tests except network-dependent ones
./scripts/test-by-tag.sh --skip network

# Run provider tests that aren't slow
./scripts/test-by-tag.sh --tag provider --skip slow

# Run edge case tests
./scripts/test-by-tag.sh --tag edgeCase
```

## Best Practices

1. **Apply tags at the Suite level** when all tests in the suite share characteristics
2. **Apply tags at the Test level** for specific tests that differ from the suite
3. **Use multiple tags** to accurately categorize tests
4. **Keep tags updated** when test characteristics change
5. **Run appropriate tag sets** in CI/CD pipelines based on the pipeline stage