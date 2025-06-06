import Foundation
import Testing
@testable import VibeMeter
import XCTest

@Suite("CursorProviderTransitionTests")
struct CursorProviderTransitionTests {
    private let cursorProvider: CursorProvider
    private let mockURLSession: MockURLSession
    private let mockSettingsManager: MockSettingsManager

    init() {
        self.mockURLSession = MockURLSession()
        self.mockSettingsManager = MockSettingsManager()
        self.cursorProvider = CursorProvider(
            urlSession: mockURLSession,
            settingsManager: mockSettingsManager)
    }

    // MARK: - User State Transition Tests

    @Test("user transition from individual to team")
    func userTransition_FromIndividualToTeam() async throws {
        // Given - Start as individual user (no session)
        let session = await mockSettingsManager.getSession(for: .cursor)
        #expect(session == nil)

        let individualInvoiceData = Data("""
        {"items": [{"cents": 1000, "description": "Individual Usage"}], "pricing_description": {"description": "Individual Plan", "id": "individual"}}
        """.utf8)

        mockURLSession.nextData = individualInvoiceData
        mockURLSession.nextResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        let individualInvoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "token",
            month: 1,
            year: 2024,
            teamId: nil)

        #expect(individualInvoice.totalSpendingCents == 1000)
        let firstRequestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let firstBodyJSON = try JSONSerialization.jsonObject(with: firstRequestBody) as? [String: Any]
        #expect(firstBodyJSON?["teamId"] == nil)

        // Fetch invoice as team member
        let teamInvoiceData = Data("""
        {"items": [{"cents": 5000, "description": "Team Usage"}], "pricing_description": {"description": "Team Plan", "id": "team-pro"}}
        """.utf8)

        mockURLSession.nextData = teamInvoiceData
        mockURLSession.nextResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        let teamInvoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "token",
            month: 2,
            year: 2024,
            teamId: nil) // Not providing teamId, should use stored value

        // Then
        #expect(teamInvoice.totalSpendingCents == 5000)

        // Verify stored teamId was used
        let secondRequestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let secondBodyJSON = try JSONSerialization.jsonObject(with: secondRequestBody) as? [String: Any]
        #expect(secondBodyJSON?["teamId"] as? Int == 5000)
    }

    func userTransition_TeamMemberLeavesTeam() async throws {
        // Given - User starts in a team
        await mockSettingsManager.updateSession(for: .cursor, session: ProviderSession(
            provider: .cursor,
            teamId: 3000,
            teamName: "Current Team",
            userEmail: "member@team.com",
            isActive: true))

        // When - User leaves team (session cleared)
        await mockSettingsManager.clearUserSessionData(for: .cursor)

        // Fetch invoice as individual
        let mockInvoiceData = Data("""
        {"items": [], "pricing_description": null}
        """.utf8)

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        let invoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "token",
            month: 3,
            year: 2024,
            teamId: nil)

        // Then - Verify no teamId in request
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        #expect(bodyJSON?["teamId"] == nil)
    }

    // MARK: - Override Behavior Tests

    @Test("explicit team id overrides stored value")
    func explicitTeamIdOverridesStoredValue() async throws {
        // Given - User has a stored team
        await mockSettingsManager.updateSession(for: .cursor, session: ProviderSession(
            provider: .cursor,
            teamId: 1111,
            teamName: "Stored Team",
            userEmail: "user@example.com",
            isActive: true))

        let mockInvoiceData = Data("""
        {"items": [{"cents": 2500, "description": "Override Team Usage"}], "pricing_description": null}
        """.utf8)

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        // When - Explicitly provide different teamId
        let invoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "token",
            month: 4,
            year: 2024,
            teamId: 9999) // Override with different team

        // Then - Verify override teamId was used
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        #expect(bodyJSON?["teamId"] as? Int == 9999)
    }

    @Test("explicit zero team id filtered")
    func explicitZeroTeamIdFiltered() async throws {
        // Given - User has a stored team
        await mockSettingsManager.updateSession(for: .cursor, session: ProviderSession(
            provider: .cursor,
            teamId: 2222,
            teamName: "Stored Team",
            userEmail: "user@example.com",
            isActive: true))

        let mockInvoiceData = Data("""
        {"items": [], "pricing_description": null}
        """.utf8)

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        // When - Explicitly provide teamId = 0
        _ = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "token",
            month: 5,
            year: 2024,
            teamId: 0) // Explicitly set to 0

        // Then - Verify teamId 0 is filtered out as invalid
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        #expect(bodyJSON?["teamId"] == nil)
        #expect(bodyJSON?["teamId"] as? Int != 2222)
    }

    func individualUser_HandlesTeamSpecificErrors() async throws {
        // Given - Individual user (no team) getting team-specific error
        let errorResponse = Data("""
        {
            "error": {
                "details": [
                    {
                        "error": "ERROR_UNAUTHORIZED",
                        "details": {
                            "detail": "Team not found"
                        }
                    }
                ]
            }
        }
        """.utf8)

        mockURLSession.nextData = errorResponse
        mockURLSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://www.cursor.com/api/dashboard/get-monthly-invoice")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil)!

        // When/Then
        do {
            _ = try await cursorProvider.fetchMonthlyInvoice(
                authToken: "token",
                month: 6,
                year: 2024,
                teamId: nil)
            Issue.record("Expected condition not met")
        } catch let error as ProviderError {
            #expect(error == .noTeamFound)
        }
    }

    func teamUser_SuccessfullyFetchesWithoutExplicitTeamId() async throws {
        // Given - Team user with stored teamId
        await mockSettingsManager.updateSession(for: .cursor, session: ProviderSession(
            provider: .cursor,
            teamId: 7777,
            teamName: "Active Team",
            userEmail: "active@team.com",
            isActive: true))

        let mockInvoiceData = Data("""
        {
            "items": [
                {"cents": 3000, "description": "Team Pro Usage"},
                {"cents": 1500, "description": "Team Additional Services"}
            ],
            "pricing_description": {"description": "Team Pro Plan", "id": "team-pro-monthly"}
        }
        """.utf8)

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        // When - Don't provide teamId, rely on stored value
        let invoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "token",
            month: 7,
            year: 2024,
            teamId: nil)

        // Then
        #expect(invoice.items.count == 2)
        #expect(invoice.pricingDescription?.description == "Team Pro Plan")
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        #expect(bodyJSON?["teamId"] as? Int == 7777)
    }

    func multipleRequestsWithChangingSessionState() async throws {
        // Test 1: No session (individual)
        var mockData = Data("""
        {"items": [{"cents": 500, "description": "Individual"}], "pricing_description": null}
        """.utf8)
        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        _ = try await cursorProvider.fetchMonthlyInvoice(authToken: "token", month: 1, year: 2024, teamId: nil)

        var requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        var bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        #expect(bodyJSON?["teamId"] == nil)
        await mockSettingsManager.updateSession(for: .cursor, session: ProviderSession(
            provider: .cursor,
            teamId: 4444,
            teamName: "New Team",
            userEmail: "user@team.com",
            isActive: true))

        mockData = Data("""
        {"items": [{"cents": 1500, "description": "Team"}], "pricing_description": null}
        """.utf8)
        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        _ = try await cursorProvider.fetchMonthlyInvoice(authToken: "token", month: 2, year: 2024, teamId: nil)

        requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        #expect(bodyJSON?["teamId"] as? Int == 4444)
        await mockSettingsManager.clearUserSessionData(for: .cursor)

        mockData = Data("""
        {"items": [{"cents": 750, "description": "Individual Again"}], "pricing_description": null}
        """.utf8)
        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        _ = try await cursorProvider.fetchMonthlyInvoice(authToken: "token", month: 3, year: 2024, teamId: nil)

        requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        #expect(bodyJSON?["teamId"] == nil)
    }
}
