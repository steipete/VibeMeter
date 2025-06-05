import Foundation
@testable import VibeMeter
import XCTest

final class CursorProviderNoTeamTests: XCTestCase {
    private var cursorProvider: CursorProvider!
    private var mockURLSession: MockURLSession!
    private var mockSettingsManager: MockSettingsManager!

    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        mockSettingsManager = MainActor.assumeIsolated { MockSettingsManager() }
        cursorProvider = CursorProvider(
            settingsManager: mockSettingsManager,
            urlSession: mockURLSession)
    }

    override func tearDown() {
        cursorProvider = nil
        mockURLSession = nil
        mockSettingsManager = nil
        super.tearDown()
    }

    // MARK: - Individual User (No Team) Tests

    func testFetchUserInfo_IndividualUser_NoTeamId() async throws {
        // Given - API returns user without teamId
        let mockUserData = Data("""
        {
            "email": "individual@example.com"
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.userInfo,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockUserData
        mockURLSession.nextResponse = mockResponse

        // When
        let userInfo = try await cursorProvider.fetchUserInfo(authToken: "individual-token")

        // Then
        XCTAssertEqual(userInfo.email, "individual@example.com")
        XCTAssertNil(userInfo.teamId, "Individual users should have nil teamId")
        XCTAssertEqual(userInfo.provider, .cursor)
    }

    func testFetchTeamInfo_IndividualUser_EmptyTeams() async throws {
        // Given - API returns empty teams array for individual users
        let mockEmptyTeamsData = Data("""
        {
            "teams": []
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.teams,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockEmptyTeamsData
        mockURLSession.nextResponse = mockResponse

        // When
        let teamInfo = try await cursorProvider.fetchTeamInfo(authToken: "individual-token")

        // Then - Should return fallback team info for individual users
        XCTAssertEqual(teamInfo.id, CursorAPIConstants.ResponseConstants.individualUserTeamId, "Individual users should get fallback team ID")
        XCTAssertEqual(teamInfo.name, CursorAPIConstants.ResponseConstants.individualUserTeamName, "Individual users should get fallback team name")
        XCTAssertEqual(teamInfo.provider, .cursor)
    }

    func testFetchMonthlyInvoice_IndividualUser_NoTeamId() async throws {
        // Given - No stored team ID and none provided (individual user)
        let mockInvoiceData = Data("""
        {
            "items": [
                {
                    "cents": 2000,
                    "description": "Individual Pro Usage"
                }
            ],
            "pricing_description": {
                "description": "Individual Pro Plan",
                "id": "individual-pro"
            }
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When
        let invoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "individual-token",
            month: 12,
            year: 2023,
            teamId: nil)

        // Then
        XCTAssertEqual(invoice.items.count, 1)
        XCTAssertEqual(invoice.items[0].cents, 2000)
        XCTAssertEqual(invoice.items[0].description, "Individual Pro Usage")
        XCTAssertEqual(invoice.totalSpendingCents, 2000)
        XCTAssertEqual(invoice.pricingDescription?.description, "Individual Pro Plan")

        // Verify request body does NOT contain teamId field
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        XCTAssertEqual(bodyJSON?["month"] as? Int, 12)
        XCTAssertEqual(bodyJSON?["year"] as? Int, 2023)
        XCTAssertNil(bodyJSON?["teamId"], "Request should not contain teamId field for individual users")
        XCTAssertEqual(bodyJSON?["includeUsageEvents"] as? Bool, false)
    }

    func testFetchMonthlyInvoice_IndividualUser_EmptyInvoice() async throws {
        // Given - Individual user with no spending
        let mockEmptyInvoiceData = Data("""
        {
            "items": [],
            "pricing_description": null
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockEmptyInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When
        let invoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "individual-token",
            month: 1,
            year: 2024,
            teamId: nil)

        // Then
        XCTAssertEqual(invoice.items.count, 0, "Individual users can have empty invoices")
        XCTAssertEqual(invoice.totalSpendingCents, 0)
        XCTAssertNil(invoice.pricingDescription)

        // Verify no teamId in request
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        XCTAssertNil(bodyJSON?["teamId"], "Request should not contain teamId field")
    }

    // MARK: - Mixed Scenarios Tests

    func testFetchMonthlyInvoice_TransitionFromTeamToIndividual() async throws {
        // Given - User was previously in a team but now is individual
        // First, set up a previous team session
        await mockSettingsManager.updateSession(for: .cursor, session: ProviderSession(
            provider: .cursor,
            teamId: 999,
            teamName: "Old Team",
            userEmail: "user@example.com",
            isActive: true))

        // Mock response for individual user invoice
        let mockInvoiceData = Data("""
        {
            "items": [{"cents": 1500, "description": "Individual Usage"}],
            "pricing_description": null
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When - Explicitly pass nil teamId to override stored value
        let invoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "individual-token",
            month: 6,
            year: 2024,
            teamId: nil)

        // Then
        XCTAssertEqual(invoice.totalSpendingCents, 1500)

        // Verify that stored teamId was used (not overridden)
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        XCTAssertEqual(bodyJSON?["teamId"] as? Int, 999, "Should use stored teamId when not explicitly overridden")
    }

    func testFetchMonthlyInvoice_ExplicitlyNoTeam() async throws {
        // Given - User has stored team but we want to fetch without team
        await mockSettingsManager.updateSession(for: .cursor, session: ProviderSession(
            provider: .cursor,
            teamId: 888,
            teamName: "Some Team",
            userEmail: "user@example.com",
            isActive: true))

        // Clear the session to simulate individual user
        await mockSettingsManager.clearUserSessionData(for: .cursor)

        let mockInvoiceData = Data("""
        {
            "items": [],
            "pricing_description": null
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When - No teamId provided and no stored session
        let invoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "individual-token",
            month: 3,
            year: 2024,
            teamId: nil)

        // Then
        XCTAssertEqual(invoice.items.count, 0)

        // Verify no teamId in request
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        XCTAssertNil(bodyJSON?["teamId"], "Should not include teamId when session is cleared")
    }

    // MARK: - API Request Body Formation Tests

    func testAPIRequestBody_WithTeamId() async throws {
        // Given
        let mockInvoiceData = Data("""
        {"items": [], "pricing_description": null}
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When - Explicitly provide teamId
        _ = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "token",
            month: 7,
            year: 2024,
            teamId: 12345)

        // Then - Verify request body includes teamId
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        
        XCTAssertEqual(bodyJSON?.count, 4, "Should have 4 fields when teamId is present")
        XCTAssertEqual(bodyJSON?["month"] as? Int, 7)
        XCTAssertEqual(bodyJSON?["year"] as? Int, 2024)
        XCTAssertEqual(bodyJSON?["teamId"] as? Int, 12345)
        XCTAssertEqual(bodyJSON?["includeUsageEvents"] as? Bool, false)
    }

    func testAPIRequestBody_WithoutTeamId() async throws {
        // Given
        let mockInvoiceData = Data("""
        {"items": [], "pricing_description": null}
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When - No teamId provided and no stored session
        _ = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "token",
            month: 8,
            year: 2024,
            teamId: nil)

        // Then - Verify request body excludes teamId
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        
        XCTAssertEqual(bodyJSON?.count, 3, "Should have only 3 fields when teamId is nil")
        XCTAssertEqual(bodyJSON?["month"] as? Int, 8)
        XCTAssertEqual(bodyJSON?["year"] as? Int, 2024)
        XCTAssertEqual(bodyJSON?["includeUsageEvents"] as? Bool, false)
        XCTAssertFalse(bodyJSON?.keys.contains("teamId") ?? false, "teamId key should not exist in request body")
    }

    func testAPIRequestBody_TeamIdZero() async throws {
        // Given - Test edge case where teamId is 0
        let mockInvoiceData = Data("""
        {"items": [], "pricing_description": null}
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When - teamId is 0 (edge case)
        _ = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "token",
            month: 9,
            year: 2024,
            teamId: 0)

        // Then - Verify request body excludes teamId since 0 is now filtered as invalid
        let requestBody = try XCTUnwrap(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        
        XCTAssertNil(bodyJSON?["teamId"], "Should not include teamId: 0 as it's filtered as invalid")
        XCTAssertFalse(bodyJSON?.keys.contains("teamId") ?? false, "teamId key should not exist when value is 0")
    }
}