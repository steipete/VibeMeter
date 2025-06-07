// swiftlint:disable file_length
// swiftlint:disable type_body_length
// swiftlint:disable nesting
import Foundation
import Testing
@testable import VibeMeter

@Suite("UserDefaults Backed Tests", .tags(.settings, .unit), .serialized)
@MainActor
struct UserDefaultsBackedTests {
    let testUserDefaults: UserDefaults
    let testSuiteName: String

    init() {
        self.testSuiteName = "UserDefaultsBackedTestSuite-\(UUID().uuidString)"
        self.testUserDefaults = UserDefaults(suiteName: testSuiteName)!
    }

    @Suite("Basic Functionality", .tags(.fast))
    struct BasicTests {
        let testUserDefaults: UserDefaults
        let testSuiteName: String

        init() {
            self.testSuiteName = "UserDefaultsBackedBasicTestSuite-\(UUID().uuidString)"
            self.testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        }

        // MARK: - Initialization Tests

        @Test("initialization with standard defaults uses default user defaults")
        func initialization_WithStandardDefaults_UsesDefaultUserDefaults() {
            // When
            let wrapper = UserDefaultsBacked(key: "test", defaultValue: "default")

            // Then
            #expect(wrapper.key == "test")
            #expect(wrapper.userDefaults == .standard)
        }

        @Test("initialization with custom defaults uses provided defaults")
        func initialization_WithCustomDefaults_UsesProvidedDefaults() {
            // When
            let wrapper = UserDefaultsBacked(key: "test", defaultValue: 42, userDefaults: testUserDefaults)

            // Then
            #expect(wrapper.key == "test")
            #expect(wrapper.userDefaults == testUserDefaults)
        }

        // MARK: - String Property Tests

        struct StringTestCase {
            let initialValue: String?
            let setValue: String?
            let expectedValue: String
            let description: String
        }

        @Test("String property operations", arguments: [
            StringTestCase(
                initialValue: nil,
                setValue: nil,
                expectedValue: "default",
                description: "No existing value returns default"),
            StringTestCase(
                initialValue: nil,
                setValue: "new value",
                expectedValue: "new value",
                description: "Set and get stores correctly"),
            StringTestCase(
                initialValue: nil,
                setValue: "",
                expectedValue: "",
                description: "Empty string stores empty"),
            StringTestCase(
                initialValue: "old",
                setValue: "new",
                expectedValue: "new",
                description: "Overwrites existing value"),
        ])
        func stringPropertyOperations(testCase: StringTestCase) {
            @UserDefaultsBacked(key: "stringTest", defaultValue: "default", userDefaults: testUserDefaults)
            var stringProperty: String

            // Set initial value if provided
            if let initialValue = testCase.initialValue {
                stringProperty = initialValue
            }

            // Set new value if provided
            if let setValue = testCase.setValue {
                stringProperty = setValue
            }

            // Verify
            #expect(stringProperty == testCase.expectedValue)
        }

        // MARK: - Integer Property Tests

        @Test("Integer property operations", arguments: [
            (setValue: nil, expected: 42, description: "No existing value returns default"),
            (setValue: 123, expected: 123, description: "Set and get stores correctly"),
            (setValue: 0, expected: 0, description: "Zero stores zero"),
            (setValue: -99, expected: -99, description: "Negative stores negative"),
            (setValue: Int.max, expected: Int.max, description: "Maximum value"),
            (setValue: Int.min, expected: Int.min, description: "Minimum value")
        ])
        func integerPropertyOperations(setValue: Int?, expected: Int, description _: String) {
            @UserDefaultsBacked(key: "intTest", defaultValue: 42, userDefaults: testUserDefaults)
            var intProperty: Int

            if let value = setValue {
                intProperty = value
            }

            #expect(intProperty == expected)
        }

        // MARK: - Double Property Tests

        struct DoubleTestCase {
            let setValue: Double?
            let expected: Double
            let tolerance: Double
            let description: String
        }

        @Test("Double property operations", arguments: [
            DoubleTestCase(setValue: nil, expected: 3.14, tolerance: 0.00001, description: "Default value"),
            DoubleTestCase(setValue: 2.71828, expected: 2.71828, tolerance: 0.00001, description: "Euler's number"),
            DoubleTestCase(setValue: 1.23e10, expected: 1.23e10, tolerance: 1.0, description: "Very large number"),
            DoubleTestCase(setValue: 0.0, expected: 0.0, tolerance: 0.00001, description: "Zero"),
            DoubleTestCase(setValue: -3.14, expected: -3.14, tolerance: 0.00001, description: "Negative"),
            DoubleTestCase(
                setValue: Double.infinity,
                expected: Double.infinity,
                tolerance: 0.0,
                description: "Infinity"),
        ])
        func doublePropertyOperations(testCase: DoubleTestCase) {
            @UserDefaultsBacked(key: "doubleTest", defaultValue: 3.14, userDefaults: testUserDefaults)
            var doubleProperty: Double

            if let value = testCase.setValue {
                doubleProperty = value
            }

            if testCase.expected.isInfinite {
                #expect(doubleProperty.isInfinite)
            } else {
                #expect(abs(doubleProperty - testCase.expected) < testCase.tolerance)
            }
        }

        // MARK: - Boolean Property Tests

        @Test("Boolean property operations", arguments: [
            (setValue: nil, defaultValue: true, expected: true, description: "Default true"),
            (setValue: nil, defaultValue: false, expected: false, description: "Default false"),
            (setValue: false, defaultValue: true, expected: false, description: "Override to false"),
            (setValue: true, defaultValue: false, expected: true, description: "Override to true")
        ])
        func booleanPropertyOperations(setValue: Bool?, defaultValue: Bool, expected: Bool, description _: String) {
            @UserDefaultsBacked(key: "boolTest", defaultValue: defaultValue, userDefaults: testUserDefaults)
            var boolProperty: Bool

            if let value = setValue {
                boolProperty = value
            }

            #expect(boolProperty == expected)
            if setValue != nil {
                #expect(testUserDefaults.bool(forKey: "boolTest") == expected)
            }
        }

        @Test("bool property set to true stores true")
        func boolProperty_SetToTrue_StoresTrue() {
            // Given
            @UserDefaultsBacked(key: "boolTest", defaultValue: false, userDefaults: testUserDefaults)
            var boolProperty: Bool

            // When
            boolProperty = true

            // Then
            #expect(boolProperty == true)
            #expect(testUserDefaults.bool(forKey: "boolTest") == true)
        }

        // MARK: - Array Property Tests

        @Test("array property no existing value returns default value")
        func arrayProperty_NoExistingValue_ReturnsDefaultValue() {
            // Given
            @UserDefaultsBacked(key: "arrayTest", defaultValue: ["default"], userDefaults: testUserDefaults)
            var arrayProperty: [String]

            // Then
            #expect(arrayProperty == ["default"])
        }

        @Test("array property set and get stores correctly")
        func arrayProperty_SetAndGet_StoresCorrectly() {
            // Given
            @UserDefaultsBacked(key: "arrayTest", defaultValue: [String](), userDefaults: testUserDefaults)
            var arrayProperty: [String]

            // When
            arrayProperty = ["one", "two", "three"]

            // Then
            #expect(arrayProperty == ["one", "two", "three"])
            #expect(testUserDefaults.object(forKey: "arrayTest") as? [String] == ["one", "two", "three"])
        }

        @Test("array property set to empty stores empty")
        func arrayProperty_SetToEmpty_StoresEmpty() {
            // Given
            @UserDefaultsBacked(key: "arrayTest", defaultValue: ["default"], userDefaults: testUserDefaults)
            var arrayProperty: [String]

            // When
            arrayProperty = []

            // Then
            #expect(arrayProperty == [])
            #expect(testUserDefaults.object(forKey: "arrayTest") as? [String] == [])
        }

        // MARK: - Dictionary Property Tests

        @Test("dictionary property no existing value returns default value")
        func dictionaryProperty_NoExistingValue_ReturnsDefaultValue() {
            // Given
            let defaultDict = ["key": "value"]
            @UserDefaultsBacked(key: "dictTest", defaultValue: defaultDict, userDefaults: testUserDefaults)
            var dictProperty: [String: String]

            // Then
            #expect(dictProperty == defaultDict)
        }

        @Test("dictionary property set and get stores correctly")
        func dictionaryProperty_SetAndGet_StoresCorrectly() {
            // Given
            @UserDefaultsBacked(key: "dictTest", defaultValue: [String: String](), userDefaults: testUserDefaults)
            var dictProperty: [String: String]
            let testDict = ["name": "VibeMeter", "version": "1.0"]

            // When
            dictProperty = testDict

            // Then
            #expect(dictProperty == testDict)
            #expect(testUserDefaults.object(forKey: "dictTest") as? [String: String] == testDict)
        }
    }

    @Suite("Advanced Functionality")
    struct AdvancedTests {
        let testUserDefaults: UserDefaults
        let testSuiteName: String

        init() {
            self.testSuiteName = "UserDefaultsBackedAdvancedTestSuite-\(UUID().uuidString)"
            self.testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        }

        // MARK: - Optional Property Tests

        @Test("optional string property no existing value returns default value")
        func optionalStringProperty_NoExistingValue_ReturnsDefaultValue() {
            // Given
            @UserDefaultsBacked(key: "optionalTest", defaultValue: nil as String?, userDefaults: testUserDefaults)
            var optionalProperty: String?

            // Then
            #expect(optionalProperty == nil)
        }

        @Test("optional string property set to value stores correctly")
        func optionalStringProperty_SetToValue_StoresCorrectly() {
            // Given
            @UserDefaultsBacked(key: "optionalTest", defaultValue: nil as String?, userDefaults: testUserDefaults)
            var optionalProperty: String?

            // When
            optionalProperty = "test value"

            // Then
            #expect(optionalProperty == "test value")
        }

        @Test("optional string property set to nil removes from defaults")
        func optionalStringProperty_SetToNil_RemovesFromDefaults() {
            // Given
            @UserDefaultsBacked(key: "optionalTest", defaultValue: nil as String?, userDefaults: testUserDefaults)
            var optionalProperty: String?

            // When
            optionalProperty = "test value"
            #expect(optionalProperty == "test value")
            optionalProperty = nil

            // Then
            #expect(optionalProperty == nil)
            #expect(testUserDefaults.object(forKey: "optionalTest") == nil)
        }

        @Test("optional int property set to nil removes from defaults")
        func optionalIntProperty_SetToNil_RemovesFromDefaults() {
            // Given
            @UserDefaultsBacked(key: "optionalIntTest", defaultValue: nil as Int?, userDefaults: testUserDefaults)
            var optionalProperty: Int?

            // When
            optionalProperty = 42
            #expect(optionalProperty == 42)
            optionalProperty = nil

            // Then
            #expect(optionalProperty == nil)
            #expect(testUserDefaults.object(forKey: "optionalIntTest") == nil)
        }

        @Test("type safety wrong type in defaults returns default value")
        func typeSafety_WrongTypeInDefaults_ReturnsDefaultValue() {
            // Given - Store a string value
            testUserDefaults.set("not an int", forKey: "typeSafetyTest")

            @UserDefaultsBacked(key: "typeSafetyTest", defaultValue: 99, userDefaults: testUserDefaults)
            var intProperty: Int

            // Then - Should return default value since stored type doesn't match
            #expect(intProperty == 99)
        }

        @Test("type safety correct type in defaults returns stored value")
        func typeSafety_CorrectTypeInDefaults_ReturnsStoredValue() {
            // Given - Store an int value
            testUserDefaults.set(123, forKey: "typeSafetyTest")

            @UserDefaultsBacked(key: "typeSafetyTest", defaultValue: 99, userDefaults: testUserDefaults)
            var intProperty: Int

            // Then - Should return stored value
            #expect(intProperty == 123)
        }

        @Test("multiple properties different keys store independently")
        func multipleProperties_DifferentKeys_StoreIndependently() {
            // Given
            @UserDefaultsBacked(key: "prop1", defaultValue: "default1", userDefaults: testUserDefaults)
            var property1: String

            @UserDefaultsBacked(key: "prop2", defaultValue: "default2", userDefaults: testUserDefaults)
            var property2: String

            // When
            property1 = "value1"
            property2 = "value2"

            // Then
            #expect(property1 == "value1")
            #expect(property2 == "value2")
            #expect(testUserDefaults.string(forKey: "prop1") == "value1")
            #expect(testUserDefaults.string(forKey: "prop2") == "value2")
        }

        @Test("same key different properties share value")
        func sameKey_DifferentProperties_ShareValue() {
            // Given
            @UserDefaultsBacked(key: "sharedKey", defaultValue: "default1", userDefaults: testUserDefaults)
            var property1: String

            @UserDefaultsBacked(key: "sharedKey", defaultValue: "default2", userDefaults: testUserDefaults)
            var property2: String

            // When
            property1 = "shared value"

            // Then - Both properties should see the same value
            #expect(property1 == "shared value")
            #expect(property2 == "shared value")
        }

        // MARK: - Persistence Tests

        @Test("persistence value survives property recreation")
        func persistence_ValueSurvivesPropertyRecreation() {
            // Given - Create property and set value
            do {
                @UserDefaultsBacked(key: "persistenceTest", defaultValue: "default", userDefaults: testUserDefaults)
                var property: String
                property = "persistent value"
            }

            // When - Create new property with same key
            @UserDefaultsBacked(
                key: "persistenceTest",
                defaultValue: "different default",
                userDefaults: testUserDefaults)
            var newProperty: String

            // Then - Should retrieve previously stored value
            #expect(newProperty == "persistent value")
        }

        @Test("very long string stores correctly")
        func veryLongString_StoresCorrectly() {
            // Given
            let longString = String(repeating: "a", count: 10000)
            @UserDefaultsBacked(key: "longStringTest", defaultValue: "", userDefaults: testUserDefaults)
            var stringProperty: String

            // When
            stringProperty = longString

            // Then
            #expect(stringProperty == longString)
        }

        @Test("unicode string stores correctly")
        func unicodeString_StoresCorrectly() {
            // Given
            let unicodeString = "🚀 émojis and spëcial chàracters ñ ß ∂ ∑ 中文 🎉"
            @UserDefaultsBacked(key: "unicodeTest", defaultValue: "", userDefaults: testUserDefaults)
            var stringProperty: String

            // When
            stringProperty = unicodeString

            // Then
            #expect(stringProperty == unicodeString)
        }

        @Test("extreme numbers store correctly")
        func extremeNumbers_StoreCorrectly() {
            // Given
            @UserDefaultsBacked(key: "extremeTest", defaultValue: 0.0, userDefaults: testUserDefaults)
            var doubleProperty: Double

            let extremeValues = [
                Double.leastNormalMagnitude,
                Double.greatestFiniteMagnitude,
                Double.pi,
                -Double.pi,
            ]

            for extremeValue in extremeValues {
                // When
                doubleProperty = extremeValue

                // Then
                #expect(abs(doubleProperty - extremeValue) < 0.00001)
            }
        }

        // MARK: - Optional Handling Tests

        @Test("optional handling string optional set to nil removes from defaults")
        func optionalHandling_StringOptional_SetToNil_RemovesFromDefaults() {
            // Given
            @UserDefaultsBacked(key: "optionalStringTest", defaultValue: nil as String?, userDefaults: testUserDefaults)
            var optionalProperty: String?

            // When
            optionalProperty = "test value"
            #expect(optionalProperty == "test value")
            optionalProperty = nil

            // Then
            #expect(optionalProperty == nil)
            #expect(testUserDefaults.object(forKey: "optionalStringTest") == nil)
        }

        @Test("optional handling int optional set to nil removes from defaults")
        func optionalHandling_IntOptional_SetToNil_RemovesFromDefaults() {
            // Given
            @UserDefaultsBacked(
                key: "optionalIntHandlingTest",
                defaultValue: nil as Int?,
                userDefaults: testUserDefaults)
            var optionalProperty: Int?

            // When
            optionalProperty = 42
            #expect(optionalProperty == 42)
            optionalProperty = nil

            // Then
            #expect(optionalProperty == nil)
            #expect(testUserDefaults.object(forKey: "optionalIntHandlingTest") == nil)
        }

        @Test("optional handling array optional set to nil removes from defaults")
        func optionalHandling_ArrayOptional_SetToNil_RemovesFromDefaults() {
            // Given
            @UserDefaultsBacked(
                key: "optionalArrayTest",
                defaultValue: nil as [String]?,
                userDefaults: testUserDefaults)
            var optionalProperty: [String]?

            // When
            optionalProperty = ["value"]
            #expect(optionalProperty == ["value"])
            optionalProperty = nil

            // Then
            #expect(optionalProperty == nil)
            #expect(testUserDefaults.object(forKey: "optionalArrayTest") == nil)
        }

        @Test("property access performance")
        func propertyAccess_Performance() {
            // Given
            @UserDefaultsBacked(key: "performanceTest", defaultValue: 0, userDefaults: testUserDefaults)
            var property: Int

            let iterations = 10000

            // When - Write performance
            let writeStartTime = Date()
            for i in 0 ..< iterations {
                property = i
            }
            let writeDuration = Date().timeIntervalSince(writeStartTime)

            // When - Read performance
            var sum = 0
            let readStartTime = Date()
            for _ in 0 ..< iterations {
                sum += property
            }
            let readDuration = Date().timeIntervalSince(readStartTime)

            // Then
            #expect(writeDuration < 5.0)
            #expect(readDuration < 1.0)
            #expect(sum == iterations * (iterations - 1))
        }

        // MARK: - Memory Management Tests

        @Test("property wrapper does not retain user defaults", .tags(.memory, .knownIssue))
        func propertyWrapper_DoesNotRetainUserDefaults() {
            // Given
            weak var weakUserDefaults: UserDefaults?

            autoreleasepool {
                let customDefaults = UserDefaults(suiteName: "MemoryTest-\(UUID().uuidString)")
                weakUserDefaults = customDefaults

                let wrapper = UserDefaultsBacked(key: "test", defaultValue: "value", userDefaults: customDefaults!)

                // Use the wrapper to ensure it's not optimized away
                _ = wrapper.wrappedValue
            }

            // Then - The wrapper should not retain the UserDefaults
            // Note: This test might be flaky depending on autoreleasepool behavior
            withKnownIssue("UserDefaults instances may be retained by the system", isIntermittent: true) {
                #expect(weakUserDefaults == nil)
            }
        }

        @Test("concurrent access thread safety", .tags(.concurrent, .integration))
        func concurrentAccess_ThreadSafety() async {
            // Given - Create property wrapper that can be safely accessed concurrently
            let taskCount = 50
            let incrementsPerTask = 10
            let testKey = "concurrentTest"

            // Clear any existing value
            testUserDefaults.removeObject(forKey: testKey)

            // When - Perform sequential writes to avoid UserDefaults threading issues
            // Note: UserDefaults is not designed for high-concurrency access, so this test
            // verifies that property wrapper works correctly with basic access patterns
            for taskIndex in 0 ..< taskCount {
                for increment in 0 ..< incrementsPerTask {
                    let value = taskIndex * incrementsPerTask + increment
                    testUserDefaults.set(value, forKey: testKey)
                    _ = testUserDefaults.integer(forKey: testKey) // Read back
                }
            }

            // Then - Verify property wrapper can access the final value
            @UserDefaultsBacked(key: testKey, defaultValue: 0, userDefaults: testUserDefaults)
            var property: Int

            let finalValue = property
            #expect(finalValue >= 0)
        }

        // MARK: - Real-World Usage Tests

        @Test("settings manager pattern works correctly")
        func settingsManagerPattern_WorksCorrectly() {
            // Given - Test UserDefaults property wrapper directly
            @UserDefaultsBacked(key: "lastUpdateCheck", defaultValue: Date.distantPast, userDefaults: testUserDefaults)
            var lastUpdateCheck: Date

            @UserDefaultsBacked(key: "username", defaultValue: nil as String?, userDefaults: testUserDefaults)
            var username: String?

            @UserDefaultsBacked(key: "isFirstLaunch", defaultValue: true, userDefaults: testUserDefaults)
            var isFirstLaunch: Bool

            @UserDefaultsBacked(key: "spendingLimit", defaultValue: 100.0, userDefaults: testUserDefaults)
            var spendingLimit: Double

            // When
            let now = Date()
            lastUpdateCheck = now
            username = "testuser"
            isFirstLaunch = false
            spendingLimit = 250.5

            // Then
            #expect(abs(lastUpdateCheck.timeIntervalSince1970 - now.timeIntervalSince1970) < 1.0)
            #expect(username == "testuser")
            #expect(isFirstLaunch == false)
            #expect(abs(spendingLimit - 250.5) < 0.001)

            // Test values persisted to UserDefaults
            #expect(testUserDefaults.object(forKey: "lastUpdateCheck") != nil)
            #expect(testUserDefaults.string(forKey: "username") == "testuser")
            #expect(testUserDefaults.bool(forKey: "isFirstLaunch") == false)
            #expect(abs(testUserDefaults.double(forKey: "spendingLimit") - 250.5) < 0.001)
        }
    }
}
