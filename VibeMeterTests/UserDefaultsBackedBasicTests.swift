@testable import VibeMeter
import XCTest

final class UserDefaultsBackedBasicTests: XCTestCase {
    var testUserDefaults: UserDefaults!
    var testSuiteName: String!

    override func setUp() {
        super.setUp()
        // Create a temporary UserDefaults instance for testing
        testSuiteName = "UserDefaultsBackedBasicTests-\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: testSuiteName)!
    }

    override func tearDown() {
        // Clean up by removing the test suite
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        testUserDefaults = nil
        testSuiteName = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization_WithStandardDefaults_UsesDefaultUserDefaults() {
        // When
        let wrapper = UserDefaultsBacked(key: "test", defaultValue: "default")

        // Then
        XCTAssertEqual(wrapper.key, "test")
        XCTAssertEqual(wrapper.defaultValue, "default")
        XCTAssertEqual(wrapper.userDefaults, .standard)
    }

    func testInitialization_WithCustomDefaults_UsesProvidedDefaults() {
        // When
        let wrapper = UserDefaultsBacked(key: "test", defaultValue: 42, userDefaults: testUserDefaults)

        // Then
        XCTAssertEqual(wrapper.key, "test")
        XCTAssertEqual(wrapper.defaultValue, 42)
        XCTAssertEqual(wrapper.userDefaults, testUserDefaults)
    }

    // MARK: - String Property Tests

    func testStringProperty_NoExistingValue_ReturnsDefaultValue() {
        // Given
        @UserDefaultsBacked(key: "stringTest", defaultValue: "default", userDefaults: testUserDefaults)
        var stringProperty: String

        // Then
        XCTAssertEqual(stringProperty, "default")
    }

    func testStringProperty_SetAndGet_StoresCorrectly() {
        // Given
        @UserDefaultsBacked(key: "stringTest", defaultValue: "default", userDefaults: testUserDefaults)
        var stringProperty: String

        // When
        stringProperty = "new value"

        // Then
        XCTAssertEqual(stringProperty, "new value")
        XCTAssertEqual(testUserDefaults.string(forKey: "stringTest"), "new value")
    }

    func testStringProperty_SetToEmptyString_StoresEmpty() {
        // Given
        @UserDefaultsBacked(key: "stringTest", defaultValue: "default", userDefaults: testUserDefaults)
        var stringProperty: String

        // When
        stringProperty = ""

        // Then
        XCTAssertEqual(stringProperty, "")
        XCTAssertEqual(testUserDefaults.string(forKey: "stringTest"), "")
    }

    // MARK: - Integer Property Tests

    func testIntProperty_NoExistingValue_ReturnsDefaultValue() {
        // Given
        @UserDefaultsBacked(key: "intTest", defaultValue: 42, userDefaults: testUserDefaults)
        var intProperty: Int

        // Then
        XCTAssertEqual(intProperty, 42)
    }

    func testIntProperty_SetAndGet_StoresCorrectly() {
        // Given
        @UserDefaultsBacked(key: "intTest", defaultValue: 42, userDefaults: testUserDefaults)
        var intProperty: Int

        // When
        intProperty = 123

        // Then
        XCTAssertEqual(intProperty, 123)
        XCTAssertEqual(testUserDefaults.integer(forKey: "intTest"), 123)
    }

    func testIntProperty_SetToZero_StoresZero() {
        // Given
        @UserDefaultsBacked(key: "intTest", defaultValue: 42, userDefaults: testUserDefaults)
        var intProperty: Int

        // When
        intProperty = 0

        // Then
        XCTAssertEqual(intProperty, 0)
        XCTAssertEqual(testUserDefaults.integer(forKey: "intTest"), 0)
    }

    func testIntProperty_SetToNegative_StoresNegative() {
        // Given
        @UserDefaultsBacked(key: "intTest", defaultValue: 42, userDefaults: testUserDefaults)
        var intProperty: Int

        // When
        intProperty = -99

        // Then
        XCTAssertEqual(intProperty, -99)
        XCTAssertEqual(testUserDefaults.integer(forKey: "intTest"), -99)
    }

    // MARK: - Double Property Tests

    func testDoubleProperty_NoExistingValue_ReturnsDefaultValue() {
        // Given
        @UserDefaultsBacked(key: "doubleTest", defaultValue: 3.14, userDefaults: testUserDefaults)
        var doubleProperty: Double

        // Then
        XCTAssertEqual(doubleProperty, 3.14, accuracy: 0.001)
    }

    func testDoubleProperty_SetAndGet_StoresCorrectly() {
        // Given
        @UserDefaultsBacked(key: "doubleTest", defaultValue: 3.14, userDefaults: testUserDefaults)
        var doubleProperty: Double

        // When
        doubleProperty = 2.71828

        // Then
        XCTAssertEqual(doubleProperty, 2.71828, accuracy: 0.00001)
        XCTAssertEqual(testUserDefaults.double(forKey: "doubleTest"), 2.71828, accuracy: 0.00001)
    }

    func testDoubleProperty_VeryLargeNumber_StoresCorrectly() {
        // Given
        @UserDefaultsBacked(key: "doubleTest", defaultValue: 0.0, userDefaults: testUserDefaults)
        var doubleProperty: Double
        let largeNumber = 1.23e10

        // When
        doubleProperty = largeNumber

        // Then
        XCTAssertEqual(doubleProperty, largeNumber, accuracy: 1.0)
        XCTAssertEqual(testUserDefaults.double(forKey: "doubleTest"), largeNumber, accuracy: 1.0)
    }

    // MARK: - Boolean Property Tests

    func testBoolProperty_NoExistingValue_ReturnsDefaultValue() {
        // Given
        @UserDefaultsBacked(key: "boolTest", defaultValue: true, userDefaults: testUserDefaults)
        var boolProperty: Bool

        // Then
        XCTAssertTrue(boolProperty)
    }

    func testBoolProperty_SetToFalse_StoresFalse() {
        // Given
        @UserDefaultsBacked(key: "boolTest", defaultValue: true, userDefaults: testUserDefaults)
        var boolProperty: Bool

        // When
        boolProperty = false

        // Then
        XCTAssertFalse(boolProperty)
        XCTAssertFalse(testUserDefaults.bool(forKey: "boolTest"))
    }

    func testBoolProperty_SetToTrue_StoresTrue() {
        // Given
        @UserDefaultsBacked(key: "boolTest", defaultValue: false, userDefaults: testUserDefaults)
        var boolProperty: Bool

        // When
        boolProperty = true

        // Then
        XCTAssertTrue(boolProperty)
        XCTAssertTrue(testUserDefaults.bool(forKey: "boolTest"))
    }

    // MARK: - Array Property Tests

    func testArrayProperty_NoExistingValue_ReturnsDefaultValue() {
        // Given
        @UserDefaultsBacked(key: "arrayTest", defaultValue: ["default"], userDefaults: testUserDefaults)
        var arrayProperty: [String]

        // Then
        XCTAssertEqual(arrayProperty, ["default"])
    }

    func testArrayProperty_SetAndGet_StoresCorrectly() {
        // Given
        @UserDefaultsBacked(key: "arrayTest", defaultValue: [String](), userDefaults: testUserDefaults)
        var arrayProperty: [String]

        // When
        arrayProperty = ["one", "two", "three"]

        // Then
        XCTAssertEqual(arrayProperty, ["one", "two", "three"])
        XCTAssertEqual(testUserDefaults.array(forKey: "arrayTest") as? [String], ["one", "two", "three"])
    }

    func testArrayProperty_SetToEmpty_StoresEmpty() {
        // Given
        @UserDefaultsBacked(key: "arrayTest", defaultValue: ["default"], userDefaults: testUserDefaults)
        var arrayProperty: [String]

        // When
        arrayProperty = []

        // Then
        XCTAssertEqual(arrayProperty, [])
        XCTAssertEqual(testUserDefaults.array(forKey: "arrayTest") as? [String], [])
    }

    // MARK: - Dictionary Property Tests

    func testDictionaryProperty_NoExistingValue_ReturnsDefaultValue() {
        // Given
        let defaultDict = ["key": "value"]
        @UserDefaultsBacked(key: "dictTest", defaultValue: defaultDict, userDefaults: testUserDefaults)
        var dictProperty: [String: String]

        // Then
        XCTAssertEqual(dictProperty, defaultDict)
    }

    func testDictionaryProperty_SetAndGet_StoresCorrectly() {
        // Given
        @UserDefaultsBacked(key: "dictTest", defaultValue: [String: String](), userDefaults: testUserDefaults)
        var dictProperty: [String: String]
        let testDict = ["name": "VibeMeter", "version": "1.0"]

        // When
        dictProperty = testDict

        // Then
        XCTAssertEqual(dictProperty, testDict)
        XCTAssertEqual(testUserDefaults.dictionary(forKey: "dictTest") as? [String: String], testDict)
    }
}
