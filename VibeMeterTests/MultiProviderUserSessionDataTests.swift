@testable import VibeMeter
import Testing

/// Tests for the MultiProviderUserSessionData observable model.
///
/// These tests follow modern SwiftUI testing principles:
/// - Fast, isolated unit tests
/// - No external dependencies or mocks needed
/// - Direct state verification
/// - Clear test boundaries and responsibilities
@Suite("MultiProviderUserSessionDataTests")
@MainActor
struct MultiProviderUserSessionDataTests {
    let userSession: MultiProviderUserSessionData    }
    // MARK: - Initial State Tests

    @Test("initial state")

    func initialState() {
        // All properties should start in logged-out state
        #expect(userSession.isLoggedInToAnyProvider == false)
        #expect(userSession.mostRecentSession == nil)
    }

    // MARK: - Login Success Tests

    @Test("handle login success  with all data  sets all properties")

    func handleLoginSuccess_WithAllData_SetsAllProperties() {
        // Arrange
        let email = "test@example.com"
        let teamName = "Test Team"
        let teamId = 12345

        // Act
        userSession.handleLoginSuccess(for: .cursor, email: email, teamName: teamName, teamId: teamId)

        // Assert
        #expect(userSession.isLoggedInToAnyProvider == true)
        #expect(userSession.loggedInProviders.contains(.cursor == true)
        #expect(session != nil)
        #expect(session?.teamName == teamName)
        #expect(session?.isLoggedIn ?? false == true)

        let mostRecent = userSession.mostRecentSession
        #expect(mostRecent != nil)
        #expect(mostRecent?.userEmail == email)

    func handleLoginSuccess_WithoutTeamData_SetsEmailOnly() {
        // Arrange
        let email = "test@example.com"

        // Act
        userSession.handleLoginSuccess(for: .cursor, email: email, teamName: nil, teamId: nil)

        // Assert
        #expect(userSession.isLoggedInToAnyProvider == true)

        let session = userSession.getSession(for: .cursor)
        #expect(session != nil)
        #expect(session?.teamName == nil)
        #expect(session?.isLoggedIn ?? false == true)

    func handleLoginSuccess_ClearsPreviousErrors() {
        // Arrange - Set some error state first
        userSession.setErrorMessage(for: .cursor, message: "Previous error")

        // Verify error is set
        let sessionWithError = userSession.getSession(for: .cursor)
        #expect(sessionWithError?.lastErrorMessage != nil)

        // Assert - Error should be cleared
        let session = userSession.getSession(for: .cursor)
        #expect(session?.lastErrorMessage == nil)

    func handleLoginFailure_SetsErrorMessage() {
        // Arrange
        let error = NSError(
            domain: "TestDomain",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: "Login failed"])

        // Act
        userSession.handleLoginFailure(for: .cursor, error: error)

        // Assert
        #expect(userSession.isLoggedIn(to: .cursor == false)
        #expect(session != nil)
        #expect(session?.lastErrorMessage == "Login failed")

    func handleLoginFailure_UnauthorizedError_ClearsSession() {
        // Arrange - First log in successfully
        userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Team", teamId: 123)
        #expect(userSession.isLoggedIn(to: .cursor == true)

        // Act
        userSession.handleLoginFailure(for: .cursor, error: unauthorizedError)

        // Assert
        #expect(userSession.isLoggedIn(to: .cursor == false)

        let session = userSession.getSession(for: .cursor)
        #expect(session?.lastErrorMessage == nil)

    func handleLogout_ClearsSessionData() {
        // Arrange - Log in first
        userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Team", teamId: 123)
        #expect(userSession.isLoggedIn(to: .cursor == true)

        // Assert
        #expect(userSession.isLoggedIn(to: .cursor == false)
        #expect(userSession.loggedInProviders.isEmpty == true)

        let session = userSession.getSession(for: .cursor)
        #expect(session == nil)

    func multipleProviders_IndependentSessions() {
        // Arrange & Act
        userSession.handleLoginSuccess(for: .cursor, email: "cursor@example.com", teamName: "Cursor Team", teamId: 111)

        // Assert
        #expect(userSession.isLoggedInToAnyProvider == true)
        #expect(userSession.loggedInProviders.count == 1)

        let cursorSession = userSession.getSession(for: .cursor)
        #expect(cursorSession != nil)
        #expect(cursorSession?.teamName == "Cursor Team")
    }

    @Test("most recent session  updates with lalogin")

    func mostRecentSession_UpdatesWithLatestLogin() {
        // Arrange & Act - Login to Cursor first
        userSession.handleLoginSuccess(for: .cursor, email: "cursor@example.com", teamName: "Cursor Team", teamId: 111)

        // First login should be most recent
        #expect(userSession.mostRecentSession?.provider == .cursor)

        // Update cursor login (should update most recent)
        userSession.handleLoginSuccess(
            for: .cursor,
            email: "updated@example.com",
            teamName: "Updated Team",
            teamId: 222)

        // Should still be cursor but with updated info
        #expect(userSession.mostRecentSession?.provider == .cursor)
        #expect(userSession.mostRecentSession?.teamName == "Updated Team")

    func logout_WithMultipleProviders_OnlyAffectsTargetProvider() {
        // Arrange - Login to Cursor
        userSession.handleLoginSuccess(for: .cursor, email: "cursor@example.com", teamName: "Cursor Team", teamId: 111)

        #expect(userSession.isLoggedInToAnyProvider == true)

        // Act - Logout from Cursor
        userSession.handleLogout(from: .cursor)

        // Assert - Only Cursor should be logged out
        #expect(userSession.isLoggedIn(to: .cursor == false) // No providers left
        #expect(userSession.loggedInProviders.isEmpty == true)

    func setErrorMessage_CreatesSessionIfNeeded() {
        // Act
        userSession.setErrorMessage(for: .cursor, message: "Test error")

        // Assert
        let session = userSession.getSession(for: .cursor)
        #expect(session != nil)
        #expect(session?.isLoggedIn ?? true == false)

    func setTeamFetchError_SetsSpecificError() {
        // Act
        userSession.setTeamFetchError(for: .cursor, message: "Team fetch failed")

        // Assert
        let session = userSession.getSession(for: .cursor)
        #expect(session != nil)
    }

    @Test("clear error  removes error message")

    func clearError_RemovesErrorMessage() {
        // Arrange
        userSession.setErrorMessage(for: .cursor, message: "Test error")
        #expect(userSession.getSession(for: .cursor != nil)

        // Act
        userSession.clearError(for: .cursor)

        // Assert
        let session = userSession.getSession(for: .cursor)
        #expect(session?.lastErrorMessage == nil)

    func getSession_NonExistentProvider_ReturnsNil() {
        // Act & Assert
        #expect(userSession.getSession(for: .cursor == nil)

    func isLoggedIn_NonExistentProvider_ReturnsFalse() {
        // Act & Assert
        #expect(userSession.isLoggedIn(to: .cursor == false)

    func handleLoginSuccess_OverwritesPreviousSession() {
        // Arrange
        userSession.handleLoginSuccess(for: .cursor, email: "old@example.com", teamName: "Old Team", teamId: 111)

        // Verify first session
        let firstSession = userSession.getSession(for: .cursor)
        #expect(firstSession?.userEmail == "old@example.com")

        // Assert - Should have new data
        let updatedSession = userSession.getSession(for: .cursor)
        #expect(updatedSession?.userEmail == "new@example.com")
        #expect(updatedSession?.teamId == 222)
    }
}
