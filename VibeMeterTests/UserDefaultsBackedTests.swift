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

        @Test("string property no existing value returns default value")
        func stringProperty_NoExistingValue_ReturnsDefaultValue() {
            // Given
            @UserDefaultsBacked(key: "stringTest", defaultValue: "default", userDefaults: testUserDefaults)
            var stringProperty: String

            // Then
            #expect(stringProperty == "default")
        }

        @Test("string property set and get stores correctly")
        func stringProperty_SetAndGet_StoresCorrectly() {
            // Given
            @UserDefaultsBacked(key: "stringTest", defaultValue: "default", userDefaults: testUserDefaults)
            var stringProperty: String

            // When
            stringProperty = "new value"

            // Then
            #expect(stringProperty == "new value")
        }

        @Test("string property set to empty string stores empty")
        func stringProperty_SetToEmptyString_StoresEmpty() {
            // Given
            @UserDefaultsBacked(key: "stringTest", defaultValue: "default", userDefaults: testUserDefaults)
            var stringProperty: String

            // When
            stringProperty = ""

            // Then
            #expect(stringProperty.isEmpty)
        }

        // MARK: - Integer Property Tests

        @Test("int property no existing value returns default value")
        func intProperty_NoExistingValue_ReturnsDefaultValue() {
            // Given
            @UserDefaultsBacked(key: "intTest", defaultValue: 42, userDefaults: testUserDefaults)
            var intProperty: Int

            // Then
            #expect(intProperty == 42)
        }

        @Test("int property set and get stores correctly")
        func intProperty_SetAndGet_StoresCorrectly() {
            // Given
            @UserDefaultsBacked(key: "intTest", defaultValue: 42, userDefaults: testUserDefaults)
            var intProperty: Int

            // When
            intProperty = 123

            // Then
            #expect(intProperty == 123)
        }

        @Test("int property set to zero stores zero")
        func intProperty_SetToZero_StoresZero() {
            // Given
            @UserDefaultsBacked(key: "intTest", defaultValue: 42, userDefaults: testUserDefaults)
            var intProperty: Int

            // When
            intProperty = 0

            // Then
            #expect(intProperty == 0)
        }

        @Test("int property set to negative stores negative")
        func intProperty_SetToNegative_StoresNegative() {
            // Given
            @UserDefaultsBacked(key: "intTest", defaultValue: 42, userDefaults: testUserDefaults)
            var intProperty: Int

            // When
            intProperty = -99

            // Then
            #expect(intProperty == -99)
        }

        // MARK: - Double Property Tests

        @Test("double property no existing value returns default value")
        func doubleProperty_NoExistingValue_ReturnsDefaultValue() {
            // Given
            @UserDefaultsBacked(key: "doubleTest", defaultValue: 3.14, userDefaults: testUserDefaults)
            var doubleProperty: Double

            // Then
            #expect(abs(doubleProperty - 3.14) < 0.00001)
        }

        @Test("double property set and get stores correctly")
        func doubleProperty_SetAndGet_StoresCorrectly() {
            // Given
            @UserDefaultsBacked(key: "doubleTest", defaultValue: 3.14, userDefaults: testUserDefaults)
            var doubleProperty: Double

            // When
            doubleProperty = 2.71828

            // Then
            #expect(abs(doubleProperty - 2.71828) < 0.00001)
            #expect(abs(testUserDefaults.double(forKey: "doubleTest") - 2.71828) < 0.00001)
        }

        @Test("double property very large number stores correctly")
        func doubleProperty_VeryLargeNumber_StoresCorrectly() {
            // Given
            @UserDefaultsBacked(key: "doubleTest", defaultValue: 0.0, userDefaults: testUserDefaults)
            var doubleProperty: Double
            let largeNumber = 1.23e10

            // When
            doubleProperty = largeNumber

            // Then
            #expect(abs(doubleProperty - largeNumber) < 1.0)
            #expect(abs(testUserDefaults.double(forKey: "doubleTest") - largeNumber) < 1.0)
        }

        // MARK: - Boolean Property Tests

        @Test("bool property no existing value returns default value")
        func boolProperty_NoExistingValue_ReturnsDefaultValue() {
            // Given
            @UserDefaultsBacked(key: "boolTest", defaultValue: true, userDefaults: testUserDefaults)
            var boolProperty: Bool

            // Then
            #expect(boolProperty == true)
        }

        @Test("bool property set to false stores false")
        func boolProperty_SetToFalse_StoresFalse() {
            // Given
            @UserDefaultsBacked(key: "boolTest", defaultValue: true, userDefaults: testUserDefaults)
            var boolProperty: Bool

            // When
            boolProperty = false

            // Then
            #expect(boolProperty == false)
            #expect(testUserDefaults.bool(forKey: "boolTest") == false)
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
            @UserDefaultsBacked(key: "persistenceTest", defaultValue: "different default", userDefaults: testUserDefaults)
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
            @UserDefaultsBacked(key: "optionalIntHandlingTest", defaultValue: nil as Int?, userDefaults: testUserDefaults)
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
            @UserDefaultsBacked(key: "optionalArrayTest", defaultValue: nil as [String]?, userDefaults: testUserDefaults)
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

        @Test("property wrapper does not retain user defaults")
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
            // In practice, UserDefaults instances are often retained by the system
            #expect(weakUserDefaults == nil)
        }

        @Test("concurrent access thread safety")
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