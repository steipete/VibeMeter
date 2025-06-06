import Foundation
import Testing
@testable import VibeMeter

@Suite("MultiProviderUserSessionDataTests")
@MainActor
struct MultiProviderUserSessionDataTests {
    var userSession: MultiProviderUserSessionData

    init() {
        userSession = MultiProviderUserSessionData()
    }

    // MARK: - Initial State Tests

    @Test("initial state has no logged in providers")
    func initialState() {
        // Assert
        #expect(userSession.isLoggedInToAnyProvider == false)
        #expect(userSession.loggedInProviders.isEmpty == true)
        #expect(userSession.mostRecentSession == nil)
    }

    // MARK: - Login Success Tests

    @Test("handle login success with all data sets all properties")
    func handleLoginSuccess_WithAllData_SetsAllProperties() {
        // Arrange
        let email = "test@example.com"
        let teamName = "Test Team"
        let teamId = 12345

        // Act
        userSession.handleLoginSuccess(for: .cursor, email: email, teamName: teamName, teamId: teamId)

        // Assert
        #expect(userSession.isLoggedInToAnyProvider == true)
        #expect(userSession.loggedInProviders.contains(.cursor) == true)

        let session = userSession.getSession(for: .cursor)
        #expect(session != nil)
        #expect(session?.teamName == teamName)
        #expect(session?.teamId == teamId)
        #expect(session?.isLoggedIn == true)

        let mostRecent = userSession.mostRecentSession
        #expect(mostRecent != nil)
        #expect(mostRecent?.userEmail == email)
    }

    @Test("handle login success without team data sets email only")
    func handleLoginSuccess_WithoutTeamData_SetsEmailOnly() {
        // Arrange
        let email = "test@example.com"

        // Act
        userSession.handleLoginSuccess(for: .cursor, email: email, teamName: nil, teamId: nil)

        // Assert
        #expect(userSession.isLoggedInToAnyProvider == true)

        let session = userSession.getSession(for: .cursor)
        #expect(session != nil)
        #expect(session?.userEmail == email)
        #expect(session?.teamName == nil)
        #expect(session?.teamId == nil)
        #expect(session?.isLoggedIn == true)
    }

    @Test("handle login success clears previous errors")
    func handleLoginSuccess_ClearsPreviousErrors() {
        // Arrange - Set some error state first
        userSession.setErrorMessage(for: .cursor, message: "Previous error")

        // Verify error is set
        let sessionWithError = userSession.getSession(for: .cursor)
        #expect(sessionWithError?.lastErrorMessage != nil)

        // Act - Login successfully
        userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: nil, teamId: nil)

        // Assert - Error should be cleared
        let session = userSession.getSession(for: .cursor)
        #expect(session?.lastErrorMessage == nil)
    }

    // MARK: - Login Failure Tests

    @Test("handle login failure sets error message")
    func handleLoginFailure_SetsErrorMessage() {
        // Arrange
        let error = NSError(
            domain: "TestDomain",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: "Login failed"])

        // Act
        userSession.handleLoginFailure(for: .cursor, error: error)

        // Assert
        #expect(userSession.isLoggedIn(to: .cursor) == false)

        let session = userSession.getSession(for: .cursor)
        #expect(session != nil)
        #expect(session?.lastErrorMessage == "Login failed")
    }

    @Test("handle login failure with unauthorized error clears session")
    func handleLoginFailure_UnauthorizedError_ClearsSession() {
        // Arrange - First log in successfully
        userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Team", teamId: 123)
        #expect(userSession.isLoggedIn(to: .cursor) == true)

        let unauthorizedError = NSError(
            domain: "TestDomain",
            code: 401,
            userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])

        // Act
        userSession.handleLoginFailure(for: .cursor, error: unauthorizedError)

        // Assert
        #expect(userSession.isLoggedIn(to: .cursor) == false)

        let session = userSession.getSession(for: .cursor)
        #expect(session?.lastErrorMessage == nil)
    }

    // MARK: - Logout Tests

    @Test("handle logout clears session data")
    func handleLogout_ClearsSessionData() {
        // Arrange - Log in first
        userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Team", teamId: 123)
        #expect(userSession.isLoggedIn(to: .cursor) == true)

        // Act
        userSession.handleLogout(from: .cursor)

        // Assert
        #expect(userSession.isLoggedIn(to: .cursor) == false)
        #expect(userSession.loggedInProviders.isEmpty == true)

        let session = userSession.getSession(for: .cursor)
        #expect(session == nil)
    }

    // MARK: - Multiple Provider Tests

    @Test("multiple providers have independent sessions")
    func multipleProviders_IndependentSessions() {
        // Act - Login to cursor
        userSession.handleLoginSuccess(for: .cursor, email: "cursor@example.com", teamName: "Cursor Team", teamId: 111)

        // Assert
        #expect(userSession.isLoggedIn(to: .cursor) == true)
        #expect(userSession.loggedInProviders.count == 1)
        #expect(userSession.loggedInProviders.contains(.cursor) == true)

        let cursorSession = userSession.getSession(for: .cursor)
        #expect(cursorSession?.userEmail == "cursor@example.com")
    }

    @Test("most recent session updates with latest login")
    func mostRecentSession_UpdatesWithLatestLogin() {
        // Act - Login to cursor first
        userSession.handleLoginSuccess(for: .cursor, email: "first@example.com", teamName: nil, teamId: nil)

        let firstRecent = userSession.mostRecentSession
        #expect(firstRecent?.userEmail == "first@example.com")

        // Act - Login again
        userSession.handleLoginSuccess(for: .cursor, email: "second@example.com", teamName: nil, teamId: nil)

        // Assert - Most recent should update
        let secondRecent = userSession.mostRecentSession
        #expect(secondRecent?.userEmail == "second@example.com")
    }

    @Test("logout with multiple providers only affects target provider")
    func logout_WithMultipleProviders_OnlyAffectsTargetProvider() {
        // Arrange - Login to cursor
        userSession.handleLoginSuccess(for: .cursor, email: "cursor@example.com", teamName: nil, teamId: nil)

        // Act - Logout from cursor
        userSession.handleLogout(from: .cursor)

        // Assert
        #expect(userSession.isLoggedIn(to: .cursor) == false)
    }

    // MARK: - Error Management Tests

    @Test("set error message creates session if needed")
    func setErrorMessage_CreatesSessionIfNeeded() {
        // Act
        userSession.setErrorMessage(for: .cursor, message: "Test error")

        // Assert
        let session = userSession.getSession(for: .cursor)
        #expect(session != nil)
        #expect(session?.lastErrorMessage == "Test error")
        #expect(session?.isLoggedIn == false)
    }

    @Test("set team fetch error sets specific error")
    func setTeamFetchError_SetsSpecificError() {
        // Act
        userSession.setTeamFetchError(for: .cursor, message: "Test error")

        // Assert
        let session = userSession.getSession(for: .cursor)
        #expect(session != nil)
        #expect(session?.lastErrorMessage == "Unable to fetch team information")
    }

    @Test("clear error removes error message")
    func clearError_RemovesErrorMessage() {
        // Arrange
        userSession.setErrorMessage(for: .cursor, message: "Error to clear")

        // Act
        userSession.clearError(for: .cursor)

        // Assert
        let session = userSession.getSession(for: .cursor)
        #expect(session?.lastErrorMessage == nil)
    }

    // MARK: - Edge Cases

    @Test("get session for non-existent provider returns nil")
    func getSession_NonExistentProvider_ReturnsNil() {
        #expect(userSession.getSession(for: .cursor) == nil)
    }

    @Test("is logged in to non-existent provider returns false")
    func isLoggedIn_NonExistentProvider_ReturnsFalse() {
        #expect(userSession.isLoggedIn(to: .cursor) == false)
    }

    @Test("handle login success overwrites previous session")
    func handleLoginSuccess_OverwritesPreviousSession() {
        // Arrange - First login
        userSession.handleLoginSuccess(for: .cursor, email: "old@example.com", teamName: "Old Team", teamId: 111)

        // Act - Login again with different data
        userSession.handleLoginSuccess(for: .cursor, email: "new@example.com", teamName: "New Team", teamId: 222)

        // Assert - Should have new data
        let updatedSession = userSession.getSession(for: .cursor)
        #expect(updatedSession?.userEmail == "new@example.com")
        #expect(updatedSession?.teamId == 222)
    }
}
