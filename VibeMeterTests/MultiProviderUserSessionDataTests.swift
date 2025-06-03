@testable import VibeMeter
import XCTest

/// Tests for the MultiProviderUserSessionData observable model.
///
/// These tests follow modern SwiftUI testing principles:
/// - Fast, isolated unit tests
/// - No external dependencies or mocks needed
/// - Direct state verification
/// - Clear test boundaries and responsibilities
@MainActor
final class MultiProviderUserSessionDataTests: XCTestCase, @unchecked Sendable {
    var userSession: MultiProviderUserSessionData!

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            userSession = MultiProviderUserSessionData()
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
        XCTAssertFalse(userSession.isLoggedInToAnyProvider)
        XCTAssertTrue(userSession.loggedInProviders.isEmpty)
        XCTAssertNil(userSession.mostRecentSession)
        XCTAssertFalse(userSession.isLoggedIn(to: .cursor))
    }

    // MARK: - Login Success Tests

    func testHandleLoginSuccess_WithAllData_SetsAllProperties() {
        // Arrange
        let email = "test@example.com"
        let teamName = "Test Team"
        let teamId = 12345

        // Act
        userSession.handleLoginSuccess(for: .cursor, email: email, teamName: teamName, teamId: teamId)

        // Assert
        XCTAssertTrue(userSession.isLoggedInToAnyProvider)
        XCTAssertTrue(userSession.isLoggedIn(to: .cursor))
        XCTAssertTrue(userSession.loggedInProviders.contains(.cursor))

        let session = userSession.getSession(for: .cursor)
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.userEmail, email)
        XCTAssertEqual(session?.teamName, teamName)
        XCTAssertEqual(session?.teamId, teamId)
        XCTAssertTrue(session?.isLoggedIn ?? false)
        XCTAssertNil(session?.lastErrorMessage)

        let mostRecent = userSession.mostRecentSession
        XCTAssertNotNil(mostRecent)
        XCTAssertEqual(mostRecent?.provider, .cursor)
        XCTAssertEqual(mostRecent?.userEmail, email)
    }

    func testHandleLoginSuccess_WithoutTeamData_SetsEmailOnly() {
        // Arrange
        let email = "test@example.com"

        // Act
        userSession.handleLoginSuccess(for: .cursor, email: email, teamName: nil, teamId: nil)

        // Assert
        XCTAssertTrue(userSession.isLoggedInToAnyProvider)
        XCTAssertTrue(userSession.isLoggedIn(to: .cursor))

        let session = userSession.getSession(for: .cursor)
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.userEmail, email)
        XCTAssertNil(session?.teamName)
        XCTAssertNil(session?.teamId)
        XCTAssertTrue(session?.isLoggedIn ?? false)
    }

    func testHandleLoginSuccess_ClearsPreviousErrors() {
        // Arrange - Set some error state first
        userSession.setErrorMessage(for: .cursor, message: "Previous error")

        // Verify error is set
        let sessionWithError = userSession.getSession(for: .cursor)
        XCTAssertNotNil(sessionWithError?.lastErrorMessage)

        // Act
        userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Team", teamId: 123)

        // Assert - Error should be cleared
        let session = userSession.getSession(for: .cursor)
        XCTAssertNil(session?.lastErrorMessage)
    }

    // MARK: - Login Failure Tests

    func testHandleLoginFailure_SetsErrorMessage() {
        // Arrange
        let error = NSError(
            domain: "TestDomain",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: "Login failed"])

        // Act
        userSession.handleLoginFailure(for: .cursor, error: error)

        // Assert
        XCTAssertFalse(userSession.isLoggedIn(to: .cursor))

        let session = userSession.getSession(for: .cursor)
        XCTAssertNotNil(session)
        XCTAssertFalse(session?.isLoggedIn ?? true)
        XCTAssertEqual(session?.lastErrorMessage, "Login failed")
    }

    func testHandleLoginFailure_UnauthorizedError_ClearsSession() {
        // Arrange - First log in successfully
        userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Team", teamId: 123)
        XCTAssertTrue(userSession.isLoggedIn(to: .cursor))

        let unauthorizedError = NSError(
            domain: "TestDomain",
            code: 401,
            userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])

        // Act
        userSession.handleLoginFailure(for: .cursor, error: unauthorizedError)

        // Assert
        XCTAssertFalse(userSession.isLoggedIn(to: .cursor))
        XCTAssertFalse(userSession.isLoggedInToAnyProvider)

        let session = userSession.getSession(for: .cursor)
        XCTAssertNil(session?.lastErrorMessage) // Unauthorized errors clear the message
    }

    // MARK: - Logout Tests

    func testHandleLogout_ClearsSessionData() {
        // Arrange - Log in first
        userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Team", teamId: 123)
        XCTAssertTrue(userSession.isLoggedIn(to: .cursor))

        // Act
        userSession.handleLogout(from: .cursor)

        // Assert
        XCTAssertFalse(userSession.isLoggedIn(to: .cursor))
        XCTAssertFalse(userSession.isLoggedInToAnyProvider)
        XCTAssertTrue(userSession.loggedInProviders.isEmpty)
        XCTAssertNil(userSession.mostRecentSession)

        let session = userSession.getSession(for: .cursor)
        XCTAssertNil(session) // Session should be completely removed
    }

    // MARK: - Multi-Provider Tests

    func testMultipleProviders_IndependentSessions() {
        // Arrange & Act
        userSession.handleLoginSuccess(for: .cursor, email: "cursor@example.com", teamName: "Cursor Team", teamId: 111)

        // Assert
        XCTAssertTrue(userSession.isLoggedInToAnyProvider)
        XCTAssertTrue(userSession.isLoggedIn(to: .cursor))
        XCTAssertEqual(userSession.loggedInProviders.count, 1)
        XCTAssertTrue(userSession.loggedInProviders.contains(.cursor))

        let cursorSession = userSession.getSession(for: .cursor)
        XCTAssertNotNil(cursorSession)
        XCTAssertEqual(cursorSession?.userEmail, "cursor@example.com")
        XCTAssertEqual(cursorSession?.teamName, "Cursor Team")
        XCTAssertEqual(cursorSession?.teamId, 111)
    }

    func testMostRecentSession_UpdatesWithLatestLogin() {
        // Arrange & Act - Login to Cursor first
        userSession.handleLoginSuccess(for: .cursor, email: "cursor@example.com", teamName: "Cursor Team", teamId: 111)

        // First login should be most recent
        XCTAssertEqual(userSession.mostRecentSession?.provider, .cursor)
        XCTAssertEqual(userSession.mostRecentSession?.userEmail, "cursor@example.com")

        // Update cursor login (should update most recent)
        userSession.handleLoginSuccess(
            for: .cursor,
            email: "updated@example.com",
            teamName: "Updated Team",
            teamId: 222)

        // Should still be cursor but with updated info
        XCTAssertEqual(userSession.mostRecentSession?.provider, .cursor)
        XCTAssertEqual(userSession.mostRecentSession?.userEmail, "updated@example.com")
        XCTAssertEqual(userSession.mostRecentSession?.teamName, "Updated Team")
    }

    func testLogout_WithMultipleProviders_OnlyAffectsTargetProvider() {
        // Arrange - Login to Cursor
        userSession.handleLoginSuccess(for: .cursor, email: "cursor@example.com", teamName: "Cursor Team", teamId: 111)

        XCTAssertTrue(userSession.isLoggedInToAnyProvider)
        XCTAssertTrue(userSession.isLoggedIn(to: .cursor))

        // Act - Logout from Cursor
        userSession.handleLogout(from: .cursor)

        // Assert - Only Cursor should be logged out
        XCTAssertFalse(userSession.isLoggedIn(to: .cursor))
        XCTAssertFalse(userSession.isLoggedInToAnyProvider) // No providers left
        XCTAssertTrue(userSession.loggedInProviders.isEmpty)
    }

    // MARK: - Error Handling Tests

    func testSetErrorMessage_CreatesSessionIfNeeded() {
        // Act
        userSession.setErrorMessage(for: .cursor, message: "Test error")

        // Assert
        let session = userSession.getSession(for: .cursor)
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.lastErrorMessage, "Test error")
        XCTAssertFalse(session?.isLoggedIn ?? true)
    }

    func testSetTeamFetchError_SetsSpecificError() {
        // Act
        userSession.setTeamFetchError(for: .cursor, message: "Team fetch failed")

        // Assert
        let session = userSession.getSession(for: .cursor)
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.lastErrorMessage, "Team fetch failed")
    }

    func testClearError_RemovesErrorMessage() {
        // Arrange
        userSession.setErrorMessage(for: .cursor, message: "Test error")
        XCTAssertNotNil(userSession.getSession(for: .cursor)?.lastErrorMessage)

        // Act
        userSession.clearError(for: .cursor)

        // Assert
        let session = userSession.getSession(for: .cursor)
        XCTAssertNil(session?.lastErrorMessage)
    }

    // MARK: - Edge Cases

    func testGetSession_NonExistentProvider_ReturnsNil() {
        // Act & Assert
        XCTAssertNil(userSession.getSession(for: .cursor))
    }

    func testIsLoggedIn_NonExistentProvider_ReturnsFalse() {
        // Act & Assert
        XCTAssertFalse(userSession.isLoggedIn(to: .cursor))
    }

    func testHandleLoginSuccess_OverwritesPreviousSession() {
        // Arrange
        userSession.handleLoginSuccess(for: .cursor, email: "old@example.com", teamName: "Old Team", teamId: 111)

        // Verify first session
        let firstSession = userSession.getSession(for: .cursor)
        XCTAssertEqual(firstSession?.userEmail, "old@example.com")

        // Act - Login again with different data
        userSession.handleLoginSuccess(for: .cursor, email: "new@example.com", teamName: "New Team", teamId: 222)

        // Assert - Should have new data
        let updatedSession = userSession.getSession(for: .cursor)
        XCTAssertEqual(updatedSession?.userEmail, "new@example.com")
        XCTAssertEqual(updatedSession?.teamName, "New Team")
        XCTAssertEqual(updatedSession?.teamId, 222)
    }
}
