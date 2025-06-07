# The Ultimate Swift Testing Playbook (2024 WWDC Edition)

A hands-on, comprehensive guide for migrating from XCTest to Swift Testing and mastering the new framework. This playbook integrates the latest patterns and best practices from WWDC 2024 and official Apple documentation to make your tests more powerful, expressive, and maintainable.

---

## **1. Migration & Tooling Baseline**

Ensure your environment is set up for a smooth, gradual migration.

| What | Why |
|---|---|
| **Xcode 16 & Swift 6** | Swift Testing is bundled with the latest toolchain. It leverages modern Swift features like macros and concurrency. |
| **Keep XCTest Targets** | **Incremental Migration is Key.** You can have XCTest and Swift Testing tests in the same target, allowing you to migrate file-by-file without breaking CI. |
| **Enable Parallel Execution**| In your Test Plan, ensure "Use parallel execution" is enabled. Swift Testing runs tests in parallel by default, which speeds up test runs and helps surface hidden state dependencies. |

### Migration Action Items
- [ ] Ensure all developer machines and CI runners are on macOS 15+ and Xcode 16+.
- [ ] For projects supporting Linux/Windows, add the `swift-testing` SPM package. It's not needed for Apple platforms.
- [ ] In your primary test plan, confirm that **“Use parallel execution”** is enabled.

---

## **2. Expressive Assertions: `#expect` & `#require`**

Replace the entire `XCTAssert` family with two powerful, expressive macros. They accept regular Swift expressions, eliminating the need for dozens of specialized `XCTAssert` functions.

| Macro | Use Case & Behavior |
|---|---|
| **`#expect(expression)`** | **Soft Check.** Use for most validations. If the expression is `false`, the issue is recorded, but the test function continues executing. This allows you to find multiple failures in a single run. |
| **`#require(expression)`**| **Hard Check.** Use for critical preconditions (e.g., unwrapping an optional). If the expression is `false` or throws, the test is immediately aborted. This prevents cascading failures from an invalid state. |

### Power Move: Optional-Safe Unwrapping
`#require` is the new, safer replacement for `XCTUnwrap`. It not only checks for `nil` but also unwraps the value for subsequent use.

```swift
// Old XCTest way
let user = try XCTUnwrap(await fetchUser())

// New, safer Swift Testing way
let user = try #require(await fetchUser())

// `user` is now a non-optional User, ready for further assertions.
#expect(user.age == 37)
```

### Action Items
- [ ] Run `grep -R "XCTAssert" .` to find all legacy assertions.
- [ ] Convert `XCTUnwrap` calls to `try #require()`.
- [ ] Convert most `XCTAssert` calls to `#expect()`. Use `#require()` only for preconditions.
- [ ] Group related checks with `#expectAll { ... }` to ensure all are evaluated and reported together.

---

## **3. Setup, Teardown, and State Lifecycle**

Swift Testing replaces `setUpWithError` and `tearDownWithError` with a more natural, type-safe lifecycle using `init()` and `deinit`.

**The Core Concept:** A fresh, new instance of the test suite (`struct` or `class`) is created for **each** test function it contains. This is the cornerstone of test isolation, guaranteeing that state from one test cannot leak into another.

| Method | Replaces... | Behavior |
|---|---|---|
| `init()` | `setUpWithError()` | The initializer for your suite. Put all setup code here. It can be `async` and `throws`. |
| `deinit` | `tearDownWithError()` | The deinitializer. Put cleanup code here. It runs automatically after each test. **Note:** `deinit` is only available on `class` or `actor` suite types, not `struct`s. This is a common reason to choose a class for your suite. |

### Practical Example: A Database Test Suite

```swift
@Suite struct DatabaseServiceTests {
    // Use `struct` by default for value semantics and state isolation.
    let sut: DatabaseService
    let tempDirectory: URL

    init() throws {
        // ARRANGE: Runs before EACH test in this suite.
        self.tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        let testDatabase = TestDatabase(storageURL: tempDirectory)
        self.sut = DatabaseService(database: testDatabase)
    }
    
    // For structs, teardown happens automatically when the value is destroyed.
    // If you need explicit cleanup (e.g., closing a connection), use a class with deinit.

    @Test func testSavingUser() throws {
        let user = User(id: "user-1", name: "Alex")
        try sut.save(user)
        #expect(try sut.loadUser(id: "user-1") != nil)
    }
}
```

### Action Items
- [ ] Convert test classes from `XCTestCase` to `struct`s (preferred) or `final class`es.
- [ ] Move `setUpWithError` logic into the suite's `init()`.
- [ ] Move `tearDownWithError` logic into the suite's `deinit` (and use a `class` if needed).
- [ ] Define the SUT and its dependencies as `let` properties, initialized in `init()`.

---

## **4. Mastering Error Handling**

Go beyond `do/catch` with a dedicated, expressive API for validating thrown errors.

| Overload | Replaces... | Example & Use Case |
|---|---|---|
| **`#expect(throws: Error.self)`**| Basic `XCTAssertThrowsError` | Verifies that *any* error was thrown. |
| **`#expect(throws: BrewingError.self)`** | Typed `XCTAssertThrowsError` | Ensures an error of a specific *type* is thrown. |
| **`#expect(throws: BrewingError.outOfBeans)`**| Specific Error `XCTAssertThrowsError`| Validates a specific error *value* is thrown. |
| **`#expect(performing:throws:)`** | `do/catch` with `switch` | **Payload Introspection.** The ultimate tool for errors with associated values. It gives you a closure to inspect the thrown error. <br> ```swift #expect(performing: { try brew(beans: 0) }, throws: { (error: BrewingError) in guard case let .notEnoughBeans(needed) = error else { return false } return needed > 0 }) ``` |
| **`#expect(throws: Never.self)`** | `XCTAssertNoThrow` | Explicitly asserts that a function does *not* throw. Ideal for happy-path tests. |

---

## **5. Parameterized Tests: Drastically Reduce Boilerplate**

Run a single test function with multiple argument sets to maximize coverage with minimal code. This is superior to a `for-in` loop because each argument set runs as an independent test, can be run in parallel, and failures are reported individually.

| Pattern | How to Use It & When |
|---|---|
| **Single Collection** | `@Test(arguments: [0, 100, -40])` <br> The simplest form. Pass a collection of inputs. |
| **Zipped Collections** | `@Test(arguments: zip(inputs, expectedOutputs))` <br> The most common and powerful pattern. Use `zip` to pair inputs and expected outputs, ensuring a one-to-one correspondence. |
| **Multiple Collections** | `@Test(arguments: ["USD", "EUR"],)` <br> **⚠️ Caution: Cartesian Product.** This creates a test case for *every possible combination* of arguments. Use it deliberately when you need to test all combinations. |

### Example using `zip`

```swift
@Test("Flavor nut content is correct", arguments: zip(
    [Flavor.vanilla, .pistachio, .chocolate],
    [false, true, false]
))
func testFlavorContainsNuts(flavor: Flavor, expected: Bool) {
    #expect(flavor.containsNuts == expected)
}
```

---

## **6. Conditional Execution & Skipping**

Dynamically control which tests run based on feature flags, environment, or known issues.

| Trait | What It Does & How to Use It |
|---|---|
| **`.disabled("Reason")`** | **Unconditionally skips a test.** The test is not run, but it is still compiled. Always provide a descriptive reason for CI visibility (e.g., `"Flaky on CI, see FB12345"`). |
| **`.enabled(if: condition)`** | **Conditionally runs a test.** The test only runs if the boolean `condition` is `true`. This is perfect for tests tied to feature flags or specific environments. <br> ```swift @Test(.enabled(if: FeatureFlags.isNewAPIEnabled)) func testNewAPI() { /* ... */ } ``` |
| **`@available(...)`** | **OS Version-Specific Tests.** Apply this attribute directly to the test function. It's better than a runtime `#available` check because it allows the test runner to know the test is skipped for platform reasons. |

---

## **7. Specialized Assertions for Clearer Failures**

While `#expect(a == b)` works, purpose-built assertions provide sharper, more actionable failure messages by explaining *why* something failed, not just *that* it failed.

| Assertion Type | Why It's Better Than a Generic Check |
| :--- | :--- |
| **Comparing Collections (Unordered)**<br>Use `#expect(collection:unorderedEquals:)` | A simple `==` check on arrays fails if elements are the same but the order is different. This specialized assertion checks for equality while ignoring order, preventing false negatives for tests where order doesn't matter. <br><br> **Brittle:** `#expect(tags == ["ios", "swift"])` <br> **Robust:** `#expect(collection: tags, unorderedEquals: ["swift", "ios"])` |
| **Floating-Point Accuracy**<br>Use `accuracy:` parameters. | Floating-point math is imprecise. `#expect(0.1 + 0.2 == 0.3)` will fail. Specialized assertions allow you to specify a tolerance, ensuring tests are robust against minor floating-point inaccuracies. <br><br> **Fails:** `#expect(result == 0.3)` <br> **Passes:** `#expect(result, toEqual: 0.3, within: 0.0001)` |

---

## **8. Structure and Organization at Scale**

Use suites and tags to manage large and complex test bases.

### Suites and Nested Suites
A `@Suite` groups related tests and can be nested for a clear hierarchy. Traits applied to a suite are inherited by all tests and nested suites within it.

### Tags for Cross-Cutting Concerns
Tags associate tests with common characteristics (e.g., `.network`, `.ui`, `.regression`) regardless of their suite. This is invaluable for filtering.

1.  **Define Tags in a Central File:**
    ```swift
    // /Tests/Support/TestTags.swift
    import Testing

    extension Tag {
        @Tag static var fast: Self
        @Tag static var regression: Self
        @Tag static var flaky: Self
    }
    ```
2.  **Apply Tags & Filter:**
    ```swift
    // Apply to a test or suite
    @Test("Username validation", .tags(.fast, .regression))
    func testUsername() { /* ... */ }

    // Run from CLI
    // swift test --filter-tag fast

    // Filter in Xcode Test Plan
    // Add "fast" to the "Include" field or "flaky" to the "Exclude" field.
    ```

---

## **9. Concurrency and Asynchronous Testing**

### Async/Await and Confirmations
- **Async Tests**: Simply mark your test function `async` and use `await`.
- **Confirmations**: To test APIs with completion handlers or that fire multiple times (like delegates or notifications), use `confirmation`.
- **`fulfillment(of:timeout:)`**: This is the global function you `await` to pause the test until your confirmations are fulfilled or a timeout is reached.

```swift
@Test("Delegate is notified 3 times")
async func testDelegateNotifications() async throws {
    let confirmation = confirmation("delegate.didUpdate was called", expectedCount: 3)
    let delegate = MockDelegate { await confirmation() }
    let sut = SystemUnderTest(delegate: delegate)

    sut.performActionThatNotifiesThreeTimes()
    
    // Explicitly wait for the confirmation to be fulfilled with a 1-second timeout.
    try await fulfillment(of: [confirmation], timeout: .seconds(1))
}
```

### Controlling Parallelism
- **`.serialized`**: Apply this trait to a `@Test` or `@Suite` to force its contents to run serially (one at a time). Use this as a temporary measure for legacy tests that are not thread-safe or have hidden state dependencies. The goal should be to refactor them to run in parallel.
- **`.timeLimit`**: A safety net to prevent hung tests from stalling CI. The more restrictive (shorter) duration wins when applied at both the suite and test level.

---

## **10. Advanced API Cookbook**

| Feature | What it Does & How to Use It |
|---|---|
| **`withKnownIssue`** | Marks a test as an **Expected Failure**. It's better than `.disabled` for known bugs. The test still runs but won't fail the suite. Crucially, if the underlying bug gets fixed and the test *passes*, `withKnownIssue` will fail, alerting you to remove it. |
| **`CustomTestStringConvertible`** | Provides custom, readable descriptions for your types in test failure logs. Conform your key models to this protocol to make debugging much easier. |
| **`.bug("JIRA-123")` Trait** | Associates a test directly with a ticket in your issue tracker. This adds invaluable context to test reports in Xcode and Xcode Cloud. |
| **`Test.current`** | A static property (`Test.current`) that gives you runtime access to the current test's metadata, such as its name, tags, and source location. Useful for advanced custom logging. |
| **`#expectAll { ... }`**| Groups multiple assertions. If any assertion inside the block fails, they are all reported together, but execution continues past the block. |

---

## **11. Migrating from XCTest**

Swift Testing and XCTest can coexist in the same target, enabling an incremental migration.

### Key Differences at a Glance

| Feature | XCTest | Swift Testing |
|---|---|---|
| **Test Discovery** | Method name must start with `test...` | `@Test` attribute on any function or method. |
| **Suite Type** | `class MyTests: XCTestCase` | `struct MyTests` (preferred), `class`, or `actor`. |
| **Assertions** | `XCTAssert...()` family of functions | `#expect()` and `#require()` macros with Swift expressions. |
| **Error Unwrapping** | `try XCTUnwrap(...)` | `try #require(...)` |
| **Setup/Teardown**| `setUpWithError()`, `tearDownWithError()` | `init()`, `deinit` (on classes/actors) |
| **Asynchronous Wait**| `XCTestExpectation` | `confirmation()` and `await fulfillment(of:timeout:)` |
| **Parallelism** | Opt-in, multi-process | Opt-out, in-process via Swift Concurrency. |

### What NOT to Migrate (Yet)
Continue using XCTest for the following, as they are not currently supported by Swift Testing:
- **UI Automation Tests** (using `XCUIApplication`)
- **Performance Tests** (using `XCTMetric` and `measure { ... }`)
- **Tests written in Objective-C**

---

## **Appendix: Evergreen Testing Principles (The F.I.R.S.T. Principles)**

These foundational principles are framework-agnostic, and Swift Testing is designed to make adhering to them easier than ever.

| Principle | Meaning | Swift Testing Application |
|---|---|---|
| **Fast** | Tests must execute in milliseconds. | Lean on default parallelism. Use `.serialized` sparingly. |
| **Isolated**| Tests must not depend on each other. | Swift Testing enforces this by creating a new suite instance for every test. Random execution order helps surface violations. |
| **Repeatable** | A test must produce the same result every time. | Control all inputs (dates, network responses) with mocks/stubs. Reset state in `init`/`deinit`. |
| **Self-Validating**| The test must automatically report pass or fail. | Use `#expect` and `#require`. Never rely on `print()` for validation. |
| **Timely**| Write tests alongside the production code. | Use parameterized tests (`@Test(arguments:)`) to easily cover edge cases as you write code. |