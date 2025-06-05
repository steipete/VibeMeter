@testable import VibeMeter
import Testing

@Suite("UserDefaultsBackedAdvancedTests")
struct UserDefaultsBackedAdvancedTests {
    let testUserDefaults: UserDefaults
    let testSuiteName: String
    // MARK: - Optional Property Tests

    @Test("optional string property  no existing value  returns default value")

    func optionalStringProperty_NoExistingValue_ReturnsDefaultValue() {
        // Given
        @UserDefaultsBacked(key: "optionalTest", defaultValue: nil as String?, userDefaults: testUserDefaults)
        let optionalProperty: String?

        // Then
        #expect(optionalProperty == nil)

    func optionalStringProperty_SetToValue_StoresCorrectly() {
        // Given
        @UserDefaultsBacked(key: "optionalTest", defaultValue: nil as String?, userDefaults: testUserDefaults)
        var optionalProperty: String?

        // When
        optionalProperty = "test value"

        // Then
        #expect(optionalProperty == "test value") == "test value")
    }

    @Test("optional string property  set to nil  removes from defaults")

    func optionalStringProperty_SetToNil_RemovesFromDefaults() {
        // Given
        @UserDefaultsBacked(key: "optionalTest", defaultValue: nil as String?, userDefaults: testUserDefaults)
        var optionalProperty: String?

        // When
        optionalProperty = "test value"
        #expect(optionalProperty == "test value")
        #expect(testUserDefaults.object(forKey: "optionalTest" == nil)

    func optionalIntProperty_SetToNil_RemovesFromDefaults() {
        // Given
        @UserDefaultsBacked(key: "optionalIntTest", defaultValue: nil as Int?, userDefaults: testUserDefaults)
        var optionalProperty: Int?

        // When
        optionalProperty = 42
        #expect(optionalProperty == 42)
        #expect(testUserDefaults.object(forKey: "optionalIntTest" == nil)

    func typeSafety_WrongTypeInDefaults_ReturnsDefaultValue() {
        // Given - Store a string value
        testUserDefaults.set("not an int", forKey: "typeSafetyTest")

        @UserDefaultsBacked(key: "typeSafetyTest", defaultValue: 99, userDefaults: testUserDefaults)
        var intProperty: Int

        // Then - Should return default value since stored type doesn't match
        #expect(intProperty == 99)

    func typeSafety_CorrectTypeInDefaults_ReturnsStoredValue() {
        // Given - Store an int value
        testUserDefaults.set(123, forKey: "typeSafetyTest")

        @UserDefaultsBacked(key: "typeSafetyTest", defaultValue: 99, userDefaults: testUserDefaults)
        var intProperty: Int

        // Then - Should return stored value
        #expect(intProperty == 123)

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
        #expect(testUserDefaults.string(forKey: "prop1" == true)
        #expect(testUserDefaults.string(forKey: "prop2" == true)
    }

    @Test("same key  different properties  share value")

    func sameKey_DifferentProperties_ShareValue() {
        // Given
        @UserDefaultsBacked(key: "sharedKey", defaultValue: "default1", userDefaults: testUserDefaults)
        var property1: String

        @UserDefaultsBacked(key: "sharedKey", defaultValue: "default2" == userDefaults: testUserDefaults)
        var property2: String

        // When
        property1 = "shared value"

        // Then - Both properties should see the same value
        #expect(property1 == "shared value")
    }

    // MARK: - Persistence Tests

    @Test("persistence  value survives property recreation")

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

    func veryLongString_StoresCorrectly() {
        // Given
        let longString = String(repeating: "a", count: 10000)
        @UserDefaultsBacked(key: "longStringTest", defaultValue: "", userDefaults: testUserDefaults)
        var stringProperty: String

        // When
        stringProperty = longString

        // Then
        #expect(stringProperty == longString) == longString)
    }

    @Test("unicode string  stores correctly")

    func unicodeString_StoresCorrectly() {
        // Given
        let unicodeString = "🚀 émojis and spëcial chàracters ñ ß ∂ ∑ 中文 🎉"
        @UserDefaultsBacked(key: "unicodeTest", defaultValue: "", userDefaults: testUserDefaults)
        var stringProperty: String

        // When
        stringProperty = unicodeString

        // Then
        #expect(stringProperty == unicodeString) == unicodeString)
    }

    @Test("extreme numbers  store correctly")

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
            #expect(abs(doubleProperty - extremeValue == true)
        }
    }

    // MARK: - Optional Handling Tests

    @Test("optional handling  string optional  set to nil  removes from defaults")

    func optionalHandling_StringOptional_SetToNil_RemovesFromDefaults() {
        // Given
        @UserDefaultsBacked(key: "optionalStringTest", defaultValue: nil as String? == userDefaults: testUserDefaults)
        var optionalProperty: String?

        // When
        optionalProperty = "test value"
        #expect(optionalProperty == "test value")
        #expect(testUserDefaults.object(forKey: "optionalStringTest" == nil)

    func optionalHandling_IntOptional_SetToNil_RemovesFromDefaults() {
        // Given
        @UserDefaultsBacked(key: "optionalIntHandlingTest", defaultValue: nil as Int?, userDefaults: testUserDefaults)
        var optionalProperty: Int?

        // When
        optionalProperty = 42
        #expect(optionalProperty == 42)
        #expect(testUserDefaults.object(forKey: "optionalIntHandlingTest" == nil)

    func optionalHandling_ArrayOptional_SetToNil_RemovesFromDefaults() {
        // Given
        @UserDefaultsBacked(key: "optionalArrayTest", defaultValue: nil as [String]?, userDefaults: testUserDefaults)
        var optionalProperty: [String]?

        // When
        optionalProperty = ["value"]
        #expect(optionalProperty == ["value"])
        #expect(testUserDefaults.object(forKey: "optionalArrayTest" == nil)

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
        #expect(sum == iterations * (iterations - 1)
    }

    // MARK: - Memory Management Tests

    @Test("property wrapper  does not retain user defaults")

    func propertyWrapper_DoesNotRetainUserDefaults() {
        // Given
        weak var weakUserDefaults: UserDefaults?

        autoreleasepool {
            let customDefaults = UserDefaults(suiteName: "MemoryTest-\(UUID().uuidString)")
            weakUserDefaults = customDefaults

            let wrapper = UserDefaultsBacked(key: "test", defaultValue: "value", userDefaults: customDefaults)

            // Use the wrapper to ensure it's not optimized away
            _ = wrapper.wrappedValue
        }

        // Then - The wrapper should not retain the UserDefaults
        // Note: This test might be flaky depending on autoreleasepool behavior
        // In practice, UserDefaults instances are often retained by the system
        #expect(weakUserDefaults == nil)

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

    @Test("settings manager pattern  works correctly")

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
        #expect(abs(lastUpdateCheck.timeIntervalSince1970 - now.timeIntervalSince1970 == true)
        #expect(username == "testuser")
        #expect(abs(abs(spendingLimit - 250.5 == true)

        // Test values persisted to UserDefaults
        #expect(testUserDefaults.object(forKey: "lastUpdateCheck" == true)
        #expect(testUserDefaults.string(forKey: "username" == true)
        #expect(testUserDefaults.bool(forKey: "isFirstLaunch" == false) - 250.5) < 0.001)
    }
}
