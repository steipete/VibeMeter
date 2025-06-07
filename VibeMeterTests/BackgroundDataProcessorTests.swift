// swiftlint:disable file_length type_body_length
// Consolidated test file requires more lines

import Foundation
import Testing
@testable import VibeMeter

// MARK: - Background Data Processor Tests

@Suite("Background Data Processor Tests", .tags(.background, .unit))
struct BackgroundDataProcessorTests {
    
    // MARK: - Basic Functionality
    
    @Suite("Basic Functionality", .tags(.fast))
    struct Basic {
        let processor: BackgroundDataProcessor
        let mockProvider: MockBackgroundProvider
        let mockDate: Date

        init() {
            self.processor = BackgroundDataProcessor()
            self.mockProvider = MockBackgroundProvider()
            self.mockDate = Date()

            // Set up mock data
            mockProvider.userInfoToReturn = ProviderUserInfo(email: "test@example.com", provider: .cursor)
            mockProvider.teamInfoToReturn = ProviderTeamInfo(id: 12345, name: "Test Team", provider: .cursor)
            mockProvider.invoiceToReturn = ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(cents: 2000, description: "Test", provider: .cursor)],
                provider: .cursor,
                month: 12,
                year: 2023)
            mockProvider.usageToReturn = ProviderUsageData(
                currentRequests: 500,
                totalRequests: 750,
                maxRequests: 10000,
                startOfMonth: mockDate,
                provider: .cursor)
        }

        // MARK: - Basic Functionality Tests

        @Test("process provider data success returns all data")
        func processProviderData_Success_ReturnsAllData() async throws {
            // When
            let result = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                using: mockProvider)

            // Then
            #expect(result.session != nil)
            #expect(result.session?.userEmail == "test@example.com")
            #expect(result.session?.teamName == "Test Team")
            #expect(result.session?.teamId == 12345)

            #expect(result.invoice != nil)
            #expect(result.invoice?.totalSpendingCents == 2000)

            #expect(result.usage != nil)
            #expect(result.usage?.currentRequests == 500)
            #expect(result.usage?.totalRequests == 750)
        }

        @Test("process with nil team info returns session without team name")
        func processWithNilTeamInfo_ReturnsSessionWithoutTeamName() async throws {
            // Given
            mockProvider.teamInfoToReturn = nil

            // When
            let result = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                using: mockProvider)

            // Then
            #expect(result.session != nil)
            #expect(result.session?.userEmail == "test@example.com")
            #expect(result.session?.teamName == nil)
            #expect(result.session?.teamId == 12345)
        }

        @Test("process with nil usage data returns nil usage")
        func processWithNilUsageData_ReturnsNilUsage() async throws {
            // Given
            mockProvider.usageToReturn = nil

            // When
            let result = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                using: mockProvider)

            // Then
            #expect(result.usage == nil)
            #expect(result.session != nil) // Other data should still be present
            #expect(result.invoice != nil)
        }

        @Test("process with empty invoice items returns valid invoice")
        func processWithEmptyInvoiceItems_ReturnsValidInvoice() async throws {
            // Given
            mockProvider.invoiceToReturn = ProviderMonthlyInvoice(
                items: [],
                provider: .cursor,
                month: 12,
                year: 2023)

            // When
            let result = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                using: mockProvider)

            // Then
            #expect(result.invoice != nil)
            #expect(result.invoice?.items.isEmpty == true)
            #expect(result.invoice?.totalSpendingCents == 0)
        }

        @Test("process different providers independently")
        func processDifferentProviders_Independently() async throws {
            // Given
            let cursorProvider = MockBackgroundProvider()
            cursorProvider.userInfoToReturn = ProviderUserInfo(
                email: "cursor@test.com",
                teamId: 111,
                provider: .cursor)

            // When
            let cursorResult = try await processor.processProviderData(
                provider: .cursor,
                authToken: "cursor-token",
                using: cursorProvider)

            // Then
            #expect(cursorResult.session?.userEmail == "cursor@test.com")
            #expect(cursorResult.session?.provider == .cursor)
        }

        @Test("process with large spending amount")
        func processWithLargeSpendingAmount() async throws {
            // Given
            mockProvider.invoiceToReturn = ProviderMonthlyInvoice(
                items: [
                    ProviderInvoiceItem(cents: 999999, description: "Large Item 1", provider: .cursor),
                    ProviderInvoiceItem(cents: 888888, description: "Large Item 2", provider: .cursor),
                ],
                provider: .cursor,
                month: 12,
                year: 2023)

            // When
            let result = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                using: mockProvider)

            // Then
            #expect(result.invoice?.totalSpendingCents == 1888887)
            #expect(result.invoice?.items.count == 2)
        }
    }
    
    // MARK: - Error Handling
    
    @Suite("Error Handling", .tags(.edgeCase))
    struct ErrorHandling {
        let processor: BackgroundDataProcessor
        let mockProvider: MockBackgroundProvider
        let mockDate = Date()

        init() {
            processor = BackgroundDataProcessor()
            mockProvider = MockBackgroundProvider()

            // Set up default mock responses
            mockProvider.userInfoToReturn = ProviderUserInfo(
                email: "test@example.com",
                teamId: 12345,
                provider: .cursor)

            mockProvider.teamInfoToReturn = ProviderTeamInfo(
                id: 12345,
                name: "Test Team",
                provider: .cursor)

            let calendar = Calendar.current
            let currentDate = Date()
            let month = calendar.component(.month, from: currentDate) - 1 // 0-based
            let year = calendar.component(.year, from: currentDate)

            mockProvider.invoiceToReturn = ProviderMonthlyInvoice(
                items: [
                    ProviderInvoiceItem(cents: 2000, description: "Test Item", provider: .cursor),
                ],
                pricingDescription: nil,
                provider: .cursor,
                month: month,
                year: year)

            mockProvider.usageToReturn = ProviderUsageData(
                currentRequests: 500,
                totalRequests: 750,
                maxRequests: 10000,
                startOfMonth: mockDate,
                provider: .cursor)
        }

        // MARK: - Error Propagation Tests

        @Test("user info fetch error propagates correctly")
        func userInfoFetchError_PropagatesCorrectly() async {
            // Given
            mockProvider.shouldThrowUserInfoError = true

            do {
                // When
                _ = try await processor.processProviderData(
                    provider: .cursor,
                    authToken: "test-token",
                    using: mockProvider)

                // Then
                Issue.record("Expected error to be thrown")
            } catch {
                // Verify error propagated
                #expect(error is MockBackgroundProvider.MockError)
            }
        }

        @Test("team info fetch error does not prevent other data")
        func teamInfoFetchError_DoesNotPreventOtherData() async throws {
            // Given
            mockProvider.shouldThrowTeamInfoError = true

            // When
            let result = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                using: mockProvider)

            // Then
            #expect(result.session != nil)
            #expect(result.session?.teamName == nil) // Team name should be nil due to error
            #expect(result.invoice != nil) // Other data should still be fetched
            #expect(result.usage != nil)
        }

        @Test("invoice fetch error results in nil invoice")
        func invoiceFetchError_ResultsInNilInvoice() async throws {
            // Given
            mockProvider.shouldThrowInvoiceError = true

            // When
            let result = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                using: mockProvider)

            // Then
            #expect(result.session != nil) // Session should still be present
            #expect(result.invoice == nil) // Invoice should be nil due to error
            #expect(result.usage != nil) // Usage should still be fetched
        }

        @Test("usage fetch error results in nil usage")
        func usageFetchError_ResultsInNilUsage() async throws {
            // Given
            mockProvider.shouldThrowUsageError = true

            // When
            let result = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                using: mockProvider)

            // Then
            #expect(result.session != nil) // Session should still be present
            #expect(result.invoice != nil) // Invoice should still be present
            #expect(result.usage == nil) // Usage should be nil due to error
        }

        @Test("multiple errors only user info error propagates")
        func multipleErrors_OnlyUserInfoErrorPropagates() async {
            // Given
            mockProvider.shouldThrowUserInfoError = true
            mockProvider.shouldThrowTeamInfoError = true
            mockProvider.shouldThrowInvoiceError = true
            mockProvider.shouldThrowUsageError = true

            do {
                // When
                _ = try await processor.processProviderData(
                    provider: .cursor,
                    authToken: "test-token",
                    using: mockProvider)

                // Then
                Issue.record("Expected error to be thrown")
            } catch {
                // Only user info error should propagate as it's critical
                #expect(error is MockBackgroundProvider.MockError)
            }
        }

        @Test("network error during processing")
        func networkErrorDuringProcessing() async {
            // Given
            let networkProvider = MockBackgroundProvider()
            networkProvider.customError = URLError(.notConnectedToInternet)
            networkProvider.shouldThrowCustomError = true

            do {
                // When
                _ = try await processor.processProviderData(
                    provider: .cursor,
                    authToken: "test-token",
                    using: networkProvider)

                // Then
                Issue.record("Expected network error to be thrown")
            } catch {
                // Verify network error propagated
                #expect(error is URLError)
            }
        }

        @Test("empty auth token processing")
        func emptyAuthTokenProcessing() async throws {
            // When
            let result = try await processor.processProviderData(
                provider: .cursor,
                authToken: "",
                using: mockProvider)

            // Then - Should still process normally
            #expect(result.session != nil)
            #expect(result.invoice != nil)
            #expect(result.usage != nil)
        }

        @Test("malformed data handling")
        func malformedDataHandling() async throws {
            // Given - Set up malformed data
            mockProvider.userInfoToReturn = ProviderUserInfo(
                email: "", // Empty email
                teamId: -1, // Invalid team ID
                provider: .cursor)

            // When
            let result = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                using: mockProvider)

            // Then - Should handle gracefully
            #expect(result.session != nil)
            #expect(result.session?.userEmail == "")
            #expect(result.session?.teamId == -1)
        }

        @Test("concurrent processing of multiple providers")
        func concurrentProcessingOfMultipleProviders() async throws {
            // Given
            let providers: [ServiceProvider] = [.cursor]
            
            // When - Process all providers concurrently
            let results = try await withThrowingTaskGroup(of: BackgroundDataProcessor.ProcessedData.self) { group in
                for provider in providers {
                    group.addTask {
                        try await self.processor.processProviderData(
                            provider: provider,
                            authToken: "token-\(provider.rawValue)",
                            using: self.mockProvider)
                    }
                }
                
                var collectedResults: [BackgroundDataProcessor.ProcessedData] = []
                for try await result in group {
                    collectedResults.append(result)
                }
                return collectedResults
            }

            // Then
            #expect(results.count == providers.count)
            for result in results {
                #expect(result.session != nil)
                #expect(result.invoice != nil)
                #expect(result.usage != nil)
            }
        }
    }
}

// MARK: - Mock Background Provider

private actor MockBackgroundProvider: ProviderProtocol {
    var lastRetrievedAuthToken: String?
    var userInfoToReturn: ProviderUserInfo?
    var teamInfoToReturn: ProviderTeamInfo?
    var invoiceToReturn: ProviderMonthlyInvoice?
    var usageToReturn: ProviderUsageData?
    
    var shouldThrowUserInfoError = false
    var shouldThrowTeamInfoError = false
    var shouldThrowInvoiceError = false
    var shouldThrowUsageError = false
    var shouldThrowCustomError = false
    var customError: Error = MockError.genericError
    
    enum MockError: Error {
        case genericError
        case userInfoError
        case teamInfoError
        case invoiceError
        case usageError
    }
    
    func verifySessionActive(authToken: String) async throws {}
    
    func getUserInfo(authToken: String) async throws -> ProviderUserInfo {
        lastRetrievedAuthToken = authToken
        
        if shouldThrowCustomError {
            throw customError
        }
        
        if shouldThrowUserInfoError {
            throw MockError.userInfoError
        }
        
        guard let userInfo = userInfoToReturn else {
            throw MockError.userInfoError
        }
        
        return userInfo
    }
    
    func getTeamInfo(for teamId: Int, authToken: String) async throws -> ProviderTeamInfo {
        if shouldThrowTeamInfoError {
            throw MockError.teamInfoError
        }
        
        guard let teamInfo = teamInfoToReturn else {
            throw MockError.teamInfoError
        }
        
        return teamInfo
    }
    
    func getCurrentMonthInvoice(for teamId: Int?, authToken: String) async throws -> ProviderMonthlyInvoice? {
        if shouldThrowInvoiceError {
            throw MockError.invoiceError
        }
        
        return invoiceToReturn
    }
    
    func getUsageData(for teamId: Int?, authToken: String) async throws -> ProviderUsageData? {
        if shouldThrowUsageError {
            throw MockError.usageError
        }
        
        return usageToReturn
    }
}

// swiftlint:enable file_length type_body_length