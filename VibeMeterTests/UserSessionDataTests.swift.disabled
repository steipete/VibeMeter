@testable import VibeMeter
import XCTest

/// Tests for the focused UserSessionData observable model.
///
/// These tests follow modern SwiftUI testing principles:
/// - Fast, isolated unit tests
/// - No external dependencies or mocks needed
/// - Direct state verification
/// - Clear test boundaries and responsibilities
@MainActor
final class UserSessionDataTests: XCTestCase, @unchecked Sendable {
    var userSession: UserSessionData!

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            userSession = UserSessionData()
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            userSession = nil
        }
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        // All properties should start in logged-out state
        XCTAssertFalse(userSession.isLoggedIn)
        XCTAssertNil(userSession.userEmail)
        XCTAssertNil(userSession.teamName)
        XCTAssertNil(userSession.lastErrorMessage)
        XCTAssertFalse(userSession.teamIdFetchFailed)
    }

    // MARK: - Login Success Tests

    func testHandleLoginSuccess_WithTeamName_SetsAllProperties() {
        // Arrange
        let email = "test@example.com"
        let teamName = "Test Team"

        // Act
        userSession.handleLoginSuccess(email: email, teamName: teamName)

        // Assert
        XCTAssertTrue(userSession.isLoggedIn)
        XCTAssertEqual(userSession.userEmail, email)
        XCTAssertEqual(userSession.teamName, teamName)
        XCTAssertNil(userSession.lastErrorMessage) // Should clear any previous errors
        XCTAssertFalse(userSession.teamIdFetchFailed) // Should clear any previous team errors
    }

    func testHandleLoginSuccess_WithoutTeamName_SetsEmailOnly() {
        // Arrange
        let email = "test@example.com"

        // Act
        userSession.handleLoginSuccess(email: email, teamName: nil)

        // Assert
        XCTAssertTrue(userSession.isLoggedIn)
        XCTAssertEqual(userSession.userEmail, email)
        XCTAssertNil(userSession.teamName)
        XCTAssertNil(userSession.lastErrorMessage)
        XCTAssertFalse(userSession.teamIdFetchFailed)
    }

    func testHandleLoginSuccess_ClearsPreviousErrors() {
        // Arrange - Set some error state first
        userSession.setErrorMessage("Previous error")
        userSession.setTeamFetchError("Team error")

        // Verify errors are set
        XCTAssertNotNil(userSession.lastErrorMessage)
        XCTAssertTrue(userSession.teamIdFetchFailed)

        // Act
        userSession.handleLoginSuccess(email: "test@example.com", teamName: "Team")

        // Assert - Errors should be cleared
        XCTAssertNil(userSession.lastErrorMessage)
        XCTAssertFalse(userSession.teamIdFetchFailed)
    }

    // MARK: - Login Failure Tests

    func testHandleLoginFailure_LoggedOutError_ClearsErrorMessage() {
        // Arrange
        let loggedOutError = NSError(
            domain: "TestDomain",
            code: 401,
            userInfo: [NSLocalizedDescriptionKey: "User logged out"])

        // Act
        userSession.handleLoginFailure(error: loggedOutError)

        // Assert
        XCTAssertFalse(userSession.isLoggedIn)
        XCTAssertNil(userSession.userEmail)
        XCTAssertNil(userSession.teamName)
        XCTAssertNil(userSession.lastErrorMessage) // Should be nil for logout errors
        XCTAssertFalse(userSession.teamIdFetchFailed)
    }

    func testHandleLoginFailure_OtherError_SetsErrorMessage() {
        // Arrange
        let networkError = NSError(
            domain: "TestDomain",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Network error"])

        // Act
        userSession.handleLoginFailure(error: networkError)

        // Assert
        XCTAssertFalse(userSession.isLoggedIn)
        XCTAssertNil(userSession.userEmail)
        XCTAssertNil(userSession.teamName)
        XCTAssertEqual(userSession.lastErrorMessage, "Login failed or cancelled.")
        XCTAssertFalse(userSession.teamIdFetchFailed)
    }

    // MARK: - Logout Tests

    func testHandleLogout_ClearsSessionData() {
        // Arrange - Set up logged-in state
        userSession.handleLoginSuccess(email: "test@example.com", teamName: "Test Team")

        // Verify logged-in state
        XCTAssertTrue(userSession.isLoggedIn)
        XCTAssertNotNil(userSession.userEmail)
        XCTAssertNotNil(userSession.teamName)

        // Act
        userSession.handleLogout()

        // Assert
        XCTAssertFalse(userSession.isLoggedIn)
        XCTAssertNil(userSession.userEmail)
        XCTAssertNil(userSession.teamName)
        XCTAssertFalse(userSession.teamIdFetchFailed)
        // Note: lastErrorMessage is kept to show logout reason if needed
    }

    // MARK: - Update User Info Tests

    func testUpdateUserInfo_UpdatesEmailAndTeam() {
        // Arrange
        let originalEmail = "old@example.com"
        let newEmail = "new@example.com"
        let newTeamName = "New Team"

        userSession.handleLoginSuccess(email: originalEmail, teamName: "Old Team")

        // Act
        userSession.updateUserInfo(email: newEmail, teamName: newTeamName)

        // Assert
        XCTAssertTrue(userSession.isLoggedIn) // Should remain logged in
        XCTAssertEqual(userSession.userEmail, newEmail)
        XCTAssertEqual(userSession.teamName, newTeamName)
    }

    func testUpdateUserInfo_WithNilTeamName() {
        // Arrange
        userSession.handleLoginSuccess(email: "test@example.com", teamName: "Team")

        // Act
        userSession.updateUserInfo(email: "new@example.com", teamName: nil)

        // Assert
        XCTAssertEqual(userSession.userEmail, "new@example.com")
        XCTAssertNil(userSession.teamName)
    }

    // MARK: - Team Fetch Error Tests

    func testSetTeamFetchError_SetsErrorState() {
        // Arrange
        let errorMessage = "Can't find your team"

        // Act
        userSession.setTeamFetchError(errorMessage)

        // Assert
        XCTAssertTrue(userSession.teamIdFetchFailed)
        XCTAssertEqual(userSession.lastErrorMessage, errorMessage)
    }

    // MARK: - Clear Error Tests

    func testClearError_ClearsAllErrors() {
        // Arrange - Set error state
        userSession.setTeamFetchError("Team error")

        // Verify error state
        XCTAssertTrue(userSession.teamIdFetchFailed)
        XCTAssertNotNil(userSession.lastErrorMessage)

        // Act
        userSession.clearError()

        // Assert
        XCTAssertFalse(userSession.teamIdFetchFailed)
        XCTAssertNil(userSession.lastErrorMessage)
    }

    // MARK: - Set Error Message Tests

    func testSetErrorMessage_UpdatesMessage() {
        // Arrange
        let errorMessage = "Custom error message"

        // Act
        userSession.setErrorMessage(errorMessage)

        // Assert
        XCTAssertEqual(userSession.lastErrorMessage, errorMessage)
        // teamIdFetchFailed should remain unchanged (false by default)
        XCTAssertFalse(userSession.teamIdFetchFailed)
    }

    func testSetErrorMessage_OverwritesPreviousMessage() {
        // Arrange
        userSession.setErrorMessage("First error")
        XCTAssertEqual(userSession.lastErrorMessage, "First error")

        // Act
        userSession.setErrorMessage("Second error")

        // Assert
        XCTAssertEqual(userSession.lastErrorMessage, "Second error")
    }

    // MARK: - Integration Tests

    func testLoginFlow_Success_Failure_Logout() {
        // Start with initial state
        XCTAssertFalse(userSession.isLoggedIn)

        // Simulate successful login
        userSession.handleLoginSuccess(email: "test@example.com", teamName: "Test Team")
        XCTAssertTrue(userSession.isLoggedIn)
        XCTAssertEqual(userSession.userEmail, "test@example.com")
        XCTAssertEqual(userSession.teamName, "Test Team")

        // Simulate logout
        userSession.handleLogout()
        XCTAssertFalse(userSession.isLoggedIn)
        XCTAssertNil(userSession.userEmail)
        XCTAssertNil(userSession.teamName)

        // Simulate failed login attempt
        let error = NSError(domain: "Test", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid credentials"])
        userSession.handleLoginFailure(error: error)
        XCTAssertFalse(userSession.isLoggedIn)
        XCTAssertEqual(userSession.lastErrorMessage, "Login failed or cancelled.")
    }
}
