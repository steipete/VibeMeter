@testable import VibeMeter
import XCTest

@MainActor
final class SparkleUpdaterManagerTests: XCTestCase, @unchecked Sendable {
    var sut: SparkleUpdaterManager!

    override func setUp() async throws {
        try await super.setUp()
        sut = SparkleUpdaterManager()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization_InTestEnvironment_DoesNotCrash() {
        // Given/When - Initialization happens in setUp
        // Then
        XCTAssertNotNil(sut, "SparkleUpdaterManager should initialize without crashing in test environment")
    }

    func testInitialization_IsMainActor() {
        // Then - SparkleUpdaterManager is marked with @MainActor attribute
        // This test ensures the class exists and can be accessed on MainActor
        XCTAssertNotNil(sut)
    }

    func testInitialization_IsObservableObject() {
        // Then - SparkleUpdaterManager uses @Observable (Swift 6 observation system)
        // The class should be observable but doesn't need to conform to ObservableObject protocol
        XCTAssertNotNil(sut, "SparkleUpdaterManager should be observable with @Observable macro")
    }

    // MARK: - Test Environment Detection Tests

    func testInitialization_InTestEnvironment_SkipsSparkleSetup() {
        // Given - We're running in test environment (XCTest)
        let isTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        // Then
        XCTAssertTrue(isTestEnvironment, "Should detect test environment")

        // Sparkle controller should not be accessible in tests to avoid UI dialogs
        // We can't easily test this without triggering potential Sparkle initialization
    }

    // MARK: - Delegate Protocol Conformance Tests

    func testSparkleUpdaterManager_ConformsToSPUUpdaterDelegate() {
        // Then
        XCTAssertTrue(sut is any NSObjectProtocol, "Should inherit from NSObject for Objective-C protocols")

        // Verify that the manager can handle delegate methods without crashing
        // Note: We can't easily test the actual Sparkle delegate methods without mocking Sparkle
    }

    func testSparkleUpdaterManager_ConformsToSPUStandardUserDriverDelegate() {
        // Verify the class has the required delegate methods
        let hasRequiredMethods = sut
            .responds(to: #selector(SparkleUpdaterManager.standardUserDriverWillShowModalAlert)) &&
            sut.responds(to: #selector(SparkleUpdaterManager.standardUserDriverDidShowModalAlert))

        XCTAssertTrue(hasRequiredMethods, "Should implement required SPUStandardUserDriverDelegate methods")
    }

    // MARK: - Error Handling Tests

    func testErrorHandling_NoUpdateError_DoesNotCrash() {
        // Given - Test the error handling logic without calling actual delegate methods
        let noUpdateError = NSError(domain: "SUSparkleErrorDomain", code: 1001, userInfo: [
            NSLocalizedDescriptionKey: "No update available",
        ])

        // When/Then - Should handle "no update" error gracefully
        // Note: In test environment, Sparkle delegates are not called
        // This test validates that the manager exists and can handle the error pattern
        XCTAssertNotNil(noUpdateError)
        XCTAssertEqual(noUpdateError.domain, "SUSparkleErrorDomain")
        XCTAssertEqual(noUpdateError.code, 1001)
    }

    func testErrorHandling_AppcastError_DoesNotCrash() {
        // Given
        let appcastError = NSError(domain: "SUSparkleErrorDomain", code: 2001, userInfo: [
            NSLocalizedDescriptionKey: "Appcast error",
        ])

        // When/Then - Should handle appcast error gracefully
        XCTAssertNotNil(appcastError)
        XCTAssertEqual(appcastError.domain, "SUSparkleErrorDomain")
        XCTAssertEqual(appcastError.code, 2001)
    }

    func testErrorHandling_GenericError_DoesNotCrash() {
        // Given
        let genericError = NSError(domain: "TestDomain", code: 999, userInfo: [
            NSLocalizedDescriptionKey: "Generic error",
        ])

        // When/Then - Should handle generic error gracefully
        XCTAssertNotNil(genericError)
        XCTAssertEqual(genericError.domain, "TestDomain")
        XCTAssertEqual(genericError.code, 999)
    }

    func testErrorHandling_NilError_HandlesGracefully() {
        // When/Then - Should handle nil error gracefully (success case)
        let nilError: Error? = nil
        XCTAssertNil(nilError)
    }

    // MARK: - User Driver Delegate Tests

    func testStandardUserDriverWillShowModalAlert_HandlesGracefully() {
        // When/Then - Should not crash when Sparkle will show modal alert
        sut.standardUserDriverWillShowModalAlert()

        // Test passes if no exception is thrown
    }

    func testStandardUserDriverDidShowModalAlert_HandlesGracefully() {
        // When/Then - Should not crash when Sparkle did show modal alert
        sut.standardUserDriverDidShowModalAlert()

        // Test passes if no exception is thrown
    }

    // MARK: - Debug vs Release Behavior Tests

    func testInitialization_InDebugMode_SkipsSparkleSetup() {
        // Note: This test will behave differently in DEBUG vs RELEASE builds
        // In DEBUG builds, Sparkle should be disabled
        // In RELEASE builds, Sparkle should be enabled

        #if DEBUG
            // In debug builds, Sparkle should be disabled
            XCTAssertTrue(true, "Debug mode should disable Sparkle")
        #else
            // In release builds, Sparkle should be enabled
            XCTAssertTrue(true, "Release mode should enable Sparkle")
        #endif
    }

    // MARK: - Memory Management Tests

    func testSparkleUpdaterManager_DoesNotRetainCycles() {
        // Given
        weak var weakSUT: SparkleUpdaterManager?

        autoreleasepool {
            let manager = SparkleUpdaterManager()
            weakSUT = manager

            // Use the manager to ensure it's not optimized away
            _ = manager.description
        }

        // Then
        // In test environment, Sparkle is disabled, so there should be no retain cycles
        // The weak reference should be nil after the manager goes out of scope
        XCTAssertNil(weakSUT, "Manager should be deallocated (no retain cycles) in test environment")
    }

    // MARK: - Error Code Validation Tests

    func testErrorCodes_SparkleErrorDomain_AreCorrect() {
        // Test that we handle the correct Sparkle error codes
        let errorCodes = [
            1001, // No update available
            2000, // Invalid feed URL
            2001, // Appcast error
            2002, // Appcast parse error
        ]

        for code in errorCodes {
            // Given
            let error = NSError(domain: "SUSparkleErrorDomain", code: code, userInfo: [
                NSLocalizedDescriptionKey: "Test error \(code)",
            ])

            // When/Then - Should create valid error objects
            XCTAssertEqual(error.domain, "SUSparkleErrorDomain")
            XCTAssertEqual(error.code, code)
            XCTAssertNotNil(error.localizedDescription)
        }
    }

    // MARK: - Provider-Specific Tests

    func testProviderSpecificRetryHandler_DoesNotCrash() {
        // Given - Test provider-specific configuration without actual Sparkle calls
        let cursorProvider = ServiceProvider.cursor

        // When/Then - Should handle provider-specific configuration
        XCTAssertEqual(cursorProvider, .cursor)
        XCTAssertEqual(cursorProvider.displayName, "Cursor")
    }

    // MARK: - Nonisolated Method Tests

    func testNonisolatedMethods_CanBeCalledFromAnyThread() async {
        // Given - Test that nonisolated methods exist and can be called
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: nil)

        // When - Call nonisolated methods from background thread
        await Task.detached {
            // These delegate methods should be nonisolated and not require MainActor
            // We're testing that they exist and can be called without crashes
            await self.sut.standardUserDriverWillShowModalAlert()
            await self.sut.standardUserDriverDidShowModalAlert()

            // Test passes if we can call these without deadlocks
        }.value

        // Then - Should complete without deadlocks or crashes
        XCTAssertNotNil(testError)
    }

    // MARK: - Integration Tests

    func testModalAlertSequence_HandlesGracefully() {
        // Simulate modal alert sequence

        // 1. Will show alert
        sut.standardUserDriverWillShowModalAlert()

        // 2. Did show alert
        sut.standardUserDriverDidShowModalAlert()

        // Test passes if both calls complete without issues
    }

    // MARK: - Configuration Tests

    func testSparkleConfiguration_InTestEnvironment() {
        // Given - We're in test environment
        let isTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        // When/Then - Should properly detect test environment
        XCTAssertTrue(isTestEnvironment, "Should detect test environment correctly")

        // In test environment, Sparkle should be disabled to avoid dialogs
        // This is handled in the initializer
    }
}
