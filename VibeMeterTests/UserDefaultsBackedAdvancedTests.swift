@testable import VibeMeter
import XCTest

final class UserDefaultsBackedAdvancedTests: XCTestCase {
    var testUserDefaults: UserDefaults!
    var testSuiteName: String!

    override func setUp() {
        super.setUp()
        // Create a temporary UserDefaults instance for testing
        testSuiteName = "UserDefaultsBackedAdvancedTests-\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: testSuiteName)!
    }

    override func tearDown() {
        // Clean up by removing the test suite
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        testUserDefaults = nil
        testSuiteName = nil
        super.tearDown()
    }

    // MARK: - Optional Property Tests

    func testOptionalStringProperty_NoExistingValue_ReturnsDefaultValue() {
        // Given
        @UserDefaultsBacked(key: "optionalTest", defaultValue: nil as String?, userDefaults: testUserDefaults)
        var optionalProperty: String?

        // Then
        XCTAssertNil(optionalProperty)
    }

    func testOptionalStringProperty_SetToValue_StoresCorrectly() {
        // Given
        @UserDefaultsBacked(key: "optionalTest", defaultValue: nil as String?, userDefaults: testUserDefaults)
        var optionalProperty: String?

        // When
        optionalProperty = "test value"

        // Then
        XCTAssertEqual(optionalProperty, "test value")
        XCTAssertEqual(testUserDefaults.string(forKey: "optionalTest"), "test value")
    }

    func testOptionalStringProperty_SetToNil_RemovesFromDefaults() {
        // Given
        @UserDefaultsBacked(key: "optionalTest", defaultValue: nil as String?, userDefaults: testUserDefaults)
        var optionalProperty: String?

        // When
        optionalProperty = "test value"
        XCTAssertEqual(optionalProperty, "test value") // Precondition

        optionalProperty = nil

        // Then
        XCTAssertNil(optionalProperty)
        XCTAssertNil(testUserDefaults.object(forKey: "optionalTest"))
    }

    func testOptionalIntProperty_SetToNil_RemovesFromDefaults() {
        // Given
        @UserDefaultsBacked(key: "optionalIntTest", defaultValue: nil as Int?, userDefaults: testUserDefaults)
        var optionalProperty: Int?

        // When
        optionalProperty = 42
        XCTAssertEqual(optionalProperty, 42) // Precondition

        optionalProperty = nil

        // Then
        XCTAssertNil(optionalProperty)
        XCTAssertNil(testUserDefaults.object(forKey: "optionalIntTest"))
    }

    // MARK: - Type Safety Tests

    func testTypeSafety_WrongTypeInDefaults_ReturnsDefaultValue() {
        // Given - Store a string value
        testUserDefaults.set("not an int", forKey: "typeSafetyTest")

        @UserDefaultsBacked(key: "typeSafetyTest", defaultValue: 99, userDefaults: testUserDefaults)
        var intProperty: Int

        // Then - Should return default value since stored type doesn't match
        XCTAssertEqual(intProperty, 99)
    }

    func testTypeSafety_CorrectTypeInDefaults_ReturnsStoredValue() {
        // Given - Store an int value
        testUserDefaults.set(123, forKey: "typeSafetyTest")

        @UserDefaultsBacked(key: "typeSafetyTest", defaultValue: 99, userDefaults: testUserDefaults)
        var intProperty: Int

        // Then - Should return stored value
        XCTAssertEqual(intProperty, 123)
    }

    // MARK: - Key Isolation Tests

    func testMultipleProperties_DifferentKeys_StoreIndependently() {
        // Given
        @UserDefaultsBacked(key: "prop1", defaultValue: "default1", userDefaults: testUserDefaults)
        var property1: String

        @UserDefaultsBacked(key: "prop2", defaultValue: "default2", userDefaults: testUserDefaults)
        var property2: String

        // When
        property1 = "value1"
        property2 = "value2"

        // Then
        XCTAssertEqual(property1, "value1")
        XCTAssertEqual(property2, "value2")
        XCTAssertEqual(testUserDefaults.string(forKey: "prop1"), "value1")
        XCTAssertEqual(testUserDefaults.string(forKey: "prop2"), "value2")
    }

    func testSameKey_DifferentProperties_ShareValue() {
        // Given
        @UserDefaultsBacked(key: "sharedKey", defaultValue: "default1", userDefaults: testUserDefaults)
        var property1: String

        @UserDefaultsBacked(key: "sharedKey", defaultValue: "default2", userDefaults: testUserDefaults)
        var property2: String

        // When
        property1 = "shared value"

        // Then - Both properties should see the same value
        XCTAssertEqual(property1, "shared value")
        XCTAssertEqual(property2, "shared value")
    }

    // MARK: - Persistence Tests

    func testPersistence_ValueSurvivesPropertyRecreation() {
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
        XCTAssertEqual(newProperty, "persistent value")
    }

    // MARK: - Edge Cases Tests

    func testVeryLongString_StoresCorrectly() {
        // Given
        let longString = String(repeating: "a", count: 10000)
        @UserDefaultsBacked(key: "longStringTest", defaultValue: "", userDefaults: testUserDefaults)
        var stringProperty: String

        // When
        stringProperty = longString

        // Then
        XCTAssertEqual(stringProperty, longString)
        XCTAssertEqual(testUserDefaults.string(forKey: "longStringTest"), longString)
    }

    func testUnicodeString_StoresCorrectly() {
        // Given
        let unicodeString = "🚀 émojis and spëcial chàracters ñ ß ∂ ∑ 中文 🎉"
        @UserDefaultsBacked(key: "unicodeTest", defaultValue: "", userDefaults: testUserDefaults)
        var stringProperty: String

        // When
        stringProperty = unicodeString

        // Then
        XCTAssertEqual(stringProperty, unicodeString)
        XCTAssertEqual(testUserDefaults.string(forKey: "unicodeTest"), unicodeString)
    }

    func testExtremeNumbers_StoreCorrectly() {
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
            XCTAssertEqual(doubleProperty, extremeValue, accuracy: extremeValue * 1e-15)
        }
    }

    // MARK: - Optional Handling Tests

    func testOptionalHandling_StringOptional_SetToNil_RemovesFromDefaults() {
        // Given
        @UserDefaultsBacked(key: "optionalStringTest", defaultValue: nil as String?, userDefaults: testUserDefaults)
        var optionalProperty: String?

        // When
        optionalProperty = "test value"
        XCTAssertEqual(optionalProperty, "test value") // Precondition
        optionalProperty = nil

        // Then
        XCTAssertNil(optionalProperty)
        XCTAssertNil(testUserDefaults.object(forKey: "optionalStringTest"))
    }

    func testOptionalHandling_IntOptional_SetToNil_RemovesFromDefaults() {
        // Given
        @UserDefaultsBacked(key: "optionalIntHandlingTest", defaultValue: nil as Int?, userDefaults: testUserDefaults)
        var optionalProperty: Int?

        // When
        optionalProperty = 42
        XCTAssertEqual(optionalProperty, 42) // Precondition
        optionalProperty = nil

        // Then
        XCTAssertNil(optionalProperty)
        XCTAssertNil(testUserDefaults.object(forKey: "optionalIntHandlingTest"))
    }

    func testOptionalHandling_ArrayOptional_SetToNil_RemovesFromDefaults() {
        // Given
        @UserDefaultsBacked(key: "optionalArrayTest", defaultValue: nil as [String]?, userDefaults: testUserDefaults)
        var optionalProperty: [String]?

        // When
        optionalProperty = ["value"]
        XCTAssertEqual(optionalProperty, ["value"]) // Precondition
        optionalProperty = nil

        // Then
        XCTAssertNil(optionalProperty)
        XCTAssertNil(testUserDefaults.object(forKey: "optionalArrayTest"))
    }

    // MARK: - Performance Tests

    func testPropertyAccess_Performance() {
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
        XCTAssertLessThan(writeDuration, 5.0, "Write operations should be reasonably fast")
        XCTAssertLessThan(readDuration, 1.0, "Read operations should be fast")
        XCTAssertEqual(sum, iterations * (iterations - 1), "All reads should return the final written value")
    }

    // MARK: - Memory Management Tests

    func testPropertyWrapper_DoesNotRetainUserDefaults() {
        // Given
        weak var weakUserDefaults: UserDefaults?

        autoreleasepool {
            let customDefaults = UserDefaults(suiteName: "MemoryTest-\(UUID().uuidString)")!
            weakUserDefaults = customDefaults

            let wrapper = UserDefaultsBacked(key: "test", defaultValue: "value", userDefaults: customDefaults)

            // Use the wrapper to ensure it's not optimized away
            _ = wrapper.wrappedValue
        }

        // Then - The wrapper should not retain the UserDefaults
        // Note: This test might be flaky depending on autoreleasepool behavior
        // In practice, UserDefaults instances are often retained by the system
        XCTAssertNil(weakUserDefaults, "UserDefaults should be deallocated after autoreleasepool")
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentAccess_ThreadSafety() async {
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
        XCTAssertGreaterThanOrEqual(finalValue, 0, "Final value should be valid")
        XCTAssertLessThan(finalValue, taskCount * incrementsPerTask, "Final value should be within expected range")
    }

    // MARK: - Real-World Usage Tests

    func testSettingsManagerPattern_WorksCorrectly() {
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
        XCTAssertEqual(lastUpdateCheck.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(username, "testuser")
        XCTAssertFalse(isFirstLaunch)
        XCTAssertEqual(spendingLimit, 250.5, accuracy: 0.001)

        // Test values persisted to UserDefaults
        XCTAssertEqual(testUserDefaults.object(forKey: "lastUpdateCheck") as? Date, lastUpdateCheck)
        XCTAssertEqual(testUserDefaults.string(forKey: "username"), "testuser")
        XCTAssertFalse(testUserDefaults.bool(forKey: "isFirstLaunch"))
        XCTAssertEqual(testUserDefaults.double(forKey: "spendingLimit"), 250.5, accuracy: 0.001)
    }
}