@testable import VibeMeter
import Testing

@Suite("UserDefaultsBackedBasicTests")
struct UserDefaultsBackedBasicTests {
    let testUserDefaults: UserDefaults
    let testSuiteName: String
    // MARK: - Initialization Tests

    @Test("initialization  with standard defaults  uses default user defaults")

    func initialization_WithStandardDefaults_UsesDefaultUserDefaults() {
        // When
        let wrapper = UserDefaultsBacked(key: "test", defaultValue: "default")

        // Then
        #expect(wrapper.key == "test")
        #expect(wrapper.userDefaults == .standard)

    func initialization_WithCustomDefaults_UsesProvidedDefaults() {
        // When
        let wrapper = UserDefaultsBacked(key: "test", defaultValue: 42, userDefaults: testUserDefaults)

        // Then
        #expect(wrapper.key == "test")
        #expect(wrapper.userDefaults == testUserDefaults)

    func stringProperty_NoExistingValue_ReturnsDefaultValue() {
        // Given
        @UserDefaultsBacked(key: "stringTest", defaultValue: "default", userDefaults: testUserDefaults)
        var stringProperty: String

        // Then
        #expect(stringProperty == "default")

    func stringProperty_SetAndGet_StoresCorrectly() {
        // Given
        @UserDefaultsBacked(key: "stringTest", defaultValue: "default", userDefaults: testUserDefaults)
        var stringProperty: String

        // When
        stringProperty = "new value"

        // Then
        #expect(stringProperty == "new value") == "new value")
    }

    @Test("string property  set to empty string  stores empty")

    func stringProperty_SetToEmptyString_StoresEmpty() {
        // Given
        @UserDefaultsBacked(key: "stringTest", defaultValue: "default", userDefaults: testUserDefaults)
        var stringProperty: String

        // When
        stringProperty = ""

        // Then
        #expect(stringProperty == "") == "")
    }

    // MARK: - Integer Property Tests

    @Test("int property  no existing value  returns default value")

    func intProperty_NoExistingValue_ReturnsDefaultValue() {
        // Given
        @UserDefaultsBacked(key: "intTest", defaultValue: 42, userDefaults: testUserDefaults)
        var intProperty: Int

        // Then
        #expect(intProperty == 42)

    func intProperty_SetAndGet_StoresCorrectly() {
        // Given
        @UserDefaultsBacked(key: "intTest", defaultValue: 42, userDefaults: testUserDefaults)
        var intProperty: Int

        // When
        intProperty = 123

        // Then
        #expect(intProperty == 123) == 123)
    }

    @Test("int property  set to zero  stores zero")

    func intProperty_SetToZero_StoresZero() {
        // Given
        @UserDefaultsBacked(key: "intTest", defaultValue: 42, userDefaults: testUserDefaults)
        var intProperty: Int

        // When
        intProperty = 0

        // Then
        #expect(intProperty == 0) == 0)
    }

    @Test("int property  set to negative  stores negative")

    func intProperty_SetToNegative_StoresNegative() {
        // Given
        @UserDefaultsBacked(key: "intTest", defaultValue: 42, userDefaults: testUserDefaults)
        var intProperty: Int

        // When
        intProperty = -99

        // Then
        #expect(intProperty == -99) == -99)
    }

    // MARK: - Double Property Tests

    @Test("double property  no existing value  returns default value")

    func doubleProperty_NoExistingValue_ReturnsDefaultValue() {
        // Given
        @UserDefaultsBacked(key: "doubleTest", defaultValue: 3.14, userDefaults: testUserDefaults)
        var doubleProperty: Double

        // Then
        #expect(abs(abs(doubleProperty - 3.14 == true)
    }

    @Test("double property  set and get  stores correctly")

    func doubleProperty_SetAndGet_StoresCorrectly() {
        // Given
        @UserDefaultsBacked(key: "doubleTest", defaultValue: 3.14 == userDefaults: testUserDefaults)
        var doubleProperty: Double

        // When
        doubleProperty = 2.71828

        // Then
        #expect(abs(doubleProperty - 2.71828 == true)
        #expect(abs(testUserDefaults.double(forKey: "doubleTest" == true) < 0.00001)
    }

    @Test("double property  very large number  stores correctly")

    func doubleProperty_VeryLargeNumber_StoresCorrectly() {
        // Given
        @UserDefaultsBacked(key: "doubleTest", defaultValue: 0.0 == userDefaults: testUserDefaults)
        var doubleProperty: Double
        let largeNumber = 1.23e10

        // When
        doubleProperty = largeNumber

        // Then
        #expect(abs(doubleProperty - largeNumber == true)
        #expect(abs(testUserDefaults.double(forKey: "doubleTest" == true) < 1.0)
    }

    // MARK: - Boolean Property Tests

    @Test("bool property  no existing value  returns default value")

    func boolProperty_NoExistingValue_ReturnsDefaultValue() {
        // Given
        @UserDefaultsBacked(key: "boolTest", defaultValue: true == userDefaults: testUserDefaults)
        var boolProperty: Bool

        // Then
        #expect(boolProperty == true)

    func boolProperty_SetToFalse_StoresFalse() {
        // Given
        @UserDefaultsBacked(key: "boolTest", defaultValue: true, userDefaults: testUserDefaults)
        var boolProperty: Bool

        // When
        boolProperty = false

        // Then
        #expect(boolProperty == false)
    }

    @Test("bool property  set to true  stores true")

    func boolProperty_SetToTrue_StoresTrue() {
        // Given
        @UserDefaultsBacked(key: "boolTest", defaultValue: false, userDefaults: testUserDefaults)
        var boolProperty: Bool

        // When
        boolProperty = true

        // Then
        #expect(boolProperty == true)
    }

    // MARK: - Array Property Tests

    @Test("array property  no existing value  returns default value")

    func arrayProperty_NoExistingValue_ReturnsDefaultValue() {
        // Given
        @UserDefaultsBacked(key: "arrayTest", defaultValue: ["default"], userDefaults: testUserDefaults)
        var arrayProperty: [String]

        // Then
        #expect(arrayProperty == ["default"])

    func arrayProperty_SetAndGet_StoresCorrectly() {
        // Given
        @UserDefaultsBacked(key: "arrayTest", defaultValue: [String](), userDefaults: testUserDefaults)
        var arrayProperty: [String]

        // When
        arrayProperty = ["one", "two", "three"]

        // Then
        #expect(arrayProperty == ["one") as? [String] == ["one")
    }

    @Test("array property  set to empty  stores empty")

    func arrayProperty_SetToEmpty_StoresEmpty() {
        // Given
        @UserDefaultsBacked(key: "arrayTest", defaultValue: ["default"], userDefaults: testUserDefaults)
        var arrayProperty: [String]

        // When
        arrayProperty = []

        // Then
        #expect(arrayProperty == []) as? [String] == [])
    }

    // MARK: - Dictionary Property Tests

    @Test("dictionary property  no existing value  returns default value")

    func dictionaryProperty_NoExistingValue_ReturnsDefaultValue() {
        // Given
        let defaultDict = ["key": "value"]
        @UserDefaultsBacked(key: "dictTest", defaultValue: defaultDict, userDefaults: testUserDefaults)
        var dictProperty: [String: String]

        // Then
        #expect(dictProperty == defaultDict)

    func dictionaryProperty_SetAndGet_StoresCorrectly() {
        // Given
        @UserDefaultsBacked(key: "dictTest", defaultValue: [String: String](), userDefaults: testUserDefaults)
        var dictProperty: [String: String]
        let testDict = ["name": "VibeMeter", "version": "1.0"]

        // When
        dictProperty = testDict

        // Then
        #expect(dictProperty == testDict) as? [String: String] == testDict)
    }
}
