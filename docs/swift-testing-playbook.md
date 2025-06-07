# Swift Testing Playbook – practical moves to level‑up the new stack

A hands‑on checklist for migrating from **XCTest** to **Swift Testing** and squeezing every drop of power out of the new API.

---

## 1. Tooling & baseline

| What | Why |
|---|---|
| **Xcode 16 + Swift 6 only** | Swift Testing is bundled; older toolchains won’t compile. |
| **Keep XCTest targets** | Lets you migrate file‑by‑file and run legacy tests in CI side‑by‑side. |

### Action items
- [ ] Make sure **macOS 14.5** (or Linux toolchain with `--enable-experimental-swift-testing`) is on every CI runner.  
- [ ] Flip test plan → **“Use parallel execution”**.  
- [ ] Add `swift-testing` SPM package *only* for Linux/Windows CI.

---

## 2. Cleaner assertions = cleaner failures

Swift Testing replaces the zoo of `XCTAssert*` calls with two macros:

| Macro | Use‑case |
|-------|----------|
| `#expect(expr)` | Soft check; test keeps running if it fails. |
| `#require(expr)` | Hard check; test bails out immediately on failure. |

Extra goodies:
* `#expect(throws:)` – one‑liner for error paths.
* `#expect(result:equals:)`, `#expect(collection:unorderedEquals:)`, etc. for domain‑specific clarity.

### Action items
- [ ] `grep -R "XCTAssert" .` → switch to `#expect` / `#require`.
- [ ] Convert hand‑rolled `do/catch` tests to `#expect(throws:)`.

---

## 3. Optional‑safety & early‑bail

`#require` lets you safely unwrap optionals inside a test _without_ crashing later:

```swift
let user: User? = try await fetchUser()
#require(user != nil)
#expect(user!.age) == 37
```

---

## 4. Readable reports

* Conform models to **`CustomTestStringConvertible`** to shrink diff noise.  
* Give every test a display name: `@Test("Login accepts valid credentials")`.

### Action items
- [ ] Add `CustomTestStringConvertible` to key value types (`Money`, `Coordinate`, …).  
- [ ] Add display names to scenario tests.

---

## 5. Parameterised tests – kill the copy‑paste

```swift
@Suite struct CurrencyTests {
    @Test(arguments: [("USD", "€"), ("GBP", "€"), ("JPY", "€")])
    func converts(_ from: String, to: String) throws { … }
}
```

* Pass any `Sendable` collection to `arguments:` – Swift Testing turns each element into its own test case.  
* Two inputs? Wrap with `zip` or use a struct tuple.

### Action items
- [ ] Replace duplicated tests (currency, locale, formatter suites) with parameterised versions.  
- [ ] Use `zip` to avoid Cartesian explosion when two collections combine.

---

## 6. Suites, nested suites & tags – structure over chaos

```swift
@Suite struct PaymentsTests {
    @Suite struct CreditCard { … }
    @Suite struct SEPA { … }

    @Tag static var regression, network, fast
}
```

Tags let you slice tests in **test plans** or CLI:

```bash
swift test --filter-tag fast
```

### Tag starter kit
```
.fast          < 200 ms
.regression
.network
.database
ui‑flaky       (temporary)
```

### Action items
- [ ] Define tag enum in `/Tests/Tags.swift`.  
- [ ] Update test plan: include `.fast`, exclude `ui‑flaky` on PR builds.

---

## 7. Managing flaky or external failures

Wrap suspect code in **`withKnownIssue("Radar‑12345") { … }`** – test shows as *Expected Failure* and doesn’t hide fresh regressions.

---

## 8. Parallel by default – but control it

Swift Testing runs **every** test concurrently.

* Mark suites or single tests with **`.serialized`** when they touch global state.  
* Nest serial suites inside one master `.serialized` suite if absolutely ordered execution is needed.

### Action items
- [ ] Identify DB‑touching tests → move into `@Suite(.serialized)`.  
- [ ] Remove shared static vars; inject fakes through the initializer.

---

## 9. Async/await & multi‑fire callbacks

* Use async APIs directly; the test itself can be `async`.  
* If the only API is callback‑based, bridge with `withCheckedContinuation`.  
* For streams that fire many times, use **confirmations** and set an expected count instead of manual counters.

---

## 10. Init / deinit replace setUp / tearDown

Plain Swift types mean you can prep state in `init()` and free it in `deinit`:

```swift
@Suite struct CacheTests {
    let sut = InMemoryCache()

    init() {
        sut.warmUp(for: .commonPaths)
    }

    deinit {
        sut.clear()
    }
}
```

### Action items
- [ ] Drop XCTest `setUp`/`tearDown`; migrate to `init`/`deinit`.  
- [ ] Make state vars immutable where possible.

---

## 11. Traits beyond tagging

* `.timeLimit(.seconds(1))` – stop runaway tests.  
* `.enabled(if: FeatureFlags.paymentsEnabled)` – skip code paths behind feature flags.

---

## 12. Migration hygiene

* Keep mixed frameworks in **separate files** to avoid interwoven lifecycles.  
* Never mix `XCTAssert` with `#expect` in the **same test** – choose one style per file.

---

## 13. CI / Xcode Cloud tips

* Store favourite tag filters in a **test plan**; Xcode Cloud honours them and surfaces tag‑based analytics.  
* During triage, rerun **just the failed parameter value** instead of the whole suite.

### Action items
- [ ] Commit `CoreFast.plan` running `.fast` & `.regression` tags only.  
- [ ] Add a “failed‑only re‑run” step in CI to speed feedback.

---

### Cheatsheet

| Macro / Trait | Quick explainer |
|---------------|-----------------|
| `#expect`     | Soft assertion |
| `#require`    | Hard assertion |
| `withKnownIssue` | Mark flaky code |
| `@Tag`        | Logical grouping |
| `.serialized` | Run sequentially |
| `.timeLimit`  | Bounds execution time |

---

**Need more sample code or automation scripts? Ping the platform team.**


---

## Appendix A – Evergreen Testing Principles (still 100 % valid in Swift Testing)

> Most unit‑testing wisdom pre‑dates Swift Testing but still matters. The checklist below borrows from classic XCTest guidelines and translates them into modern Swift Testing equivalents.fileciteturn1file0

### FIRST Principles
| Letter | What it means | Swift Testing tip |
| ------ | ------------- | ----------------- |
| **F – Fast** | Tests should run in milliseconds. | Lean on automatic concurrency; keep `.serialized` suites small. |
| **I – Isolated** | No external dependencies. | Inject fakes or use in‑memory stores. |
| **R – Repeatable** | Results must be deterministic. | Randomise seeds inside the test, not the code; reset global state in `deinit`. |
| **S – Self‑validating** | Pass/fail must be automatic. | Use `#expect`/`#require` — never `print`. |
| **T – Timely** | Tests shouldn’t take longer to write than the production code. | Prefer parameterised tests over copy‑paste suites. |

### Test the Public API
Focus on behaviour, not implementation details—cover private helpers by exercising the public methods that use them.fileciteturn1file0

### Naming pattern
`test_<behaviour>_when<condition>_should<expectation>`  
In Swift Testing the attribute can hold that phrase:

```swift
@Test("add(_:when input is empty) should return 0")
func add_empty_returnsZero() { … }
```

### AAA (Arrange–Act–Assert)
Keep the structure explicit — blank lines between stages help readability. The idiom still pairs nicely with the single‑line `#expect` calls.fileciteturn1file0

### Avoid logic in tests
If you catch yourself writing `if`, `for`, `switch`, or complex math inside a test, extract helpers or compare against a literal.fileciteturn1file0

### One act, one assertion
Prefer one behavioural action per test and one primary expectation. When several assertions are genuinely needed, group them with `#expectAll { … }` to keep the report tidy.

### Specialised assertions
Choose purpose‑built macros (`#expect(result:equals:)`, `#expect(collection:unorderedEquals:)`) instead of generic boolean checks; they give sharper failure messages.fileciteturn1file0

### Simple values & floating‑point accuracy
Pick undeniable constants (e.g. `sqrt(4) == 2`) and use `accuracy:` overloads to compare floats.

### Ban magic strings
Extract constants or enums for repeated literals; your IDE’s autocomplete becomes the single source of truth.fileciteturn1file0

### Automatic mock generation
Tools like **Sourcery** still shine. Generate mocks for protocols, then wrap them in `#require(mock.calls.count == 1)` to assert behaviour instead of hand‑rolling spies.fileciteturn1file0

### Prefer helper factories over shared state
Factory methods that build the SUT per test beat a global `setUp()`. In Swift Testing, pass the constructed SUT into your test’s init and keep it immutable.

### UI testing strategy
- Snapshot tests for **layout**
- Unit tests for **content logic**
Keep end‑to‑end `XCUI` tests to a minimum to save CI minutes.

---

*This appendix cross‑references proven wisdom so your team can keep habits intact while embracing the new macros and concurrency model.*
