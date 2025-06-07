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
                providerClient: mockProvider)

            // Then
            #expect(result.userInfo.email == "test@example.com")
            #expect(result.teamInfo.name == "Test Team")
            #expect(result.teamInfo.id == 12345)

            #expect(result.invoice.totalSpendingCents == 2000)

            #expect(result.usage.currentRequests == 500)
            #expect(result.usage.totalRequests == 750)
        }

        @Test("process with nil team info returns fallback team")
        func processWithNilTeamInfo_ReturnsFallbackTeam() async throws {
            // Given
            mockProvider.shouldThrowTeamInfoError = true

            // When
            let result = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider)

            // Then
            #expect(result.userInfo.email == "test@example.com")
            #expect(result.teamInfo.name == "Individual Account")
            #expect(result.teamInfo.id == 0)
        }

        @Test("process with nil usage data returns fallback usage")
        func processWithNilUsageData_ReturnsFallbackUsage() async throws {
            // Given
            mockProvider.shouldThrowUsageError = true

            // When
            let result = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider)

            // Then
            #expect(result.usage.currentRequests == 0)
            #expect(result.usage.totalRequests == 0)
            #expect(result.usage.maxRequests == nil)
            #expect(result.userInfo.email == "test@example.com") // Other data should still be present
            #expect(result.invoice.totalSpendingCents == 2000)
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
                providerClient: mockProvider)

            // Then
            #expect(result.invoice.items.isEmpty == true)
            #expect(result.invoice.totalSpendingCents == 0)
        }

        @Test("process different providers independently")
        func processDifferentProviders_Independently() async throws {
            // Given
            let cursorProvider = MockBackgroundProvider()
            cursorProvider.userInfoToReturn = ProviderUserInfo(
                email: "cursor@test.com",
                teamId: 111,
                provider: .cursor)
            cursorProvider.teamInfoToReturn = ProviderTeamInfo(id: 111, name: "Cursor Team", provider: .cursor)
            cursorProvider.invoiceToReturn = ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(cents: 1000, description: "Test", provider: .cursor)],
                provider: .cursor,
                month: 11,
                year: 2023)
            cursorProvider.usageToReturn = ProviderUsageData(
                currentRequests: 100,
                totalRequests: 200,
                maxRequests: 1000,
                startOfMonth: Date(),
                provider: .cursor)

            // When
            let cursorResult = try await processor.processProviderData(
                provider: .cursor,
                authToken: "cursor-token",
                providerClient: cursorProvider)

            // Then
            #expect(cursorResult.userInfo.email == "cursor@test.com")
            #expect(cursorResult.userInfo.provider == .cursor)
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
                providerClient: mockProvider)

            // Then
            #expect(result.invoice.totalSpendingCents == 1888887)
            #expect(result.invoice.items.count == 2)
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
                    providerClient: mockProvider)

                // Then
                #expect(Bool(false), "Expected TestError to be thrown")
            } catch {
                // Verify error propagated
                #expect(error is TestError)
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
                providerClient: mockProvider)

            // Then
            #expect(result.userInfo.email == "test@example.com")
            #expect(result.teamInfo.name == "Individual Account") // Fallback team should be used
            #expect(result.teamInfo.id == 0)
            #expect(result.invoice.totalSpendingCents == 2000) // Other data should still be fetched
            #expect(result.usage.currentRequests == 500)
        }

        @Test("invoice fetch error propagates correctly")
        func invoiceFetchError_PropagatesCorrectly() async {
            // Given
            mockProvider.shouldThrowInvoiceError = true

            do {
                // When
                _ = try await processor.processProviderData(
                    provider: .cursor,
                    authToken: "test-token",
                    providerClient: mockProvider)

                // Then
                #expect(Bool(false), "Expected TestError to be thrown")
            } catch {
                // Verify error propagated
                #expect(error is TestError)
            }
        }

        @Test("usage fetch error results in fallback usage")
        func usageFetchError_ResultsInFallbackUsage() async throws {
            // Given
            mockProvider.shouldThrowUsageError = true

            // When
            let result = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider)

            // Then
            #expect(result.userInfo.email == "test@example.com") // Session should still be present
            #expect(result.invoice.totalSpendingCents == 2000) // Invoice should still be present
            #expect(result.usage.currentRequests == 0) // Usage should be fallback with zero values
            #expect(result.usage.totalRequests == 0)
            #expect(result.usage.maxRequests == nil)
        }

        @Test("multiple errors only critical errors propagate")
        func multipleErrors_OnlyCriticalErrorsPropagate() async {
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
                    providerClient: mockProvider)

                // Then
                #expect(Bool(false), "Expected critical error to be thrown")
            } catch {
                // User info error should propagate first as it's called first
                #expect(error is TestError)
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
                    providerClient: networkProvider)

                // Then
                #expect(Bool(false), "Expected network error to be thrown")
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
                providerClient: mockProvider)

            // Then - Should still process normally
            #expect(result.userInfo.email == "test@example.com")
            #expect(result.invoice.totalSpendingCents == 2000)
            #expect(result.usage.currentRequests == 500)
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
                providerClient: mockProvider)

            // Then - Should handle gracefully
            #expect(result.userInfo.email == "")
            #expect(result.userInfo.teamId == -1)
        }

        @Test("concurrent processing of multiple providers")
        func concurrentProcessingOfMultipleProviders() async throws {
            // Given
            let providers: [ServiceProvider] = [.cursor]
            
            // When - Process all providers concurrently
            let results = try await withThrowingTaskGroup(of: ProviderDataResult.self) { group in
                for provider in providers {
                    group.addTask {
                        try await self.processor.processProviderData(
                            provider: provider,
                            authToken: "token-\(provider.rawValue)",
                            providerClient: self.mockProvider)
                    }
                }
                
                var collectedResults: [ProviderDataResult] = []
                for try await result in group {
                    collectedResults.append(result)
                }
                return collectedResults
            }

            // Then
            #expect(results.count == providers.count)
            for result in results {
                #expect(result.userInfo.email == "test@example.com")
                #expect(result.invoice.totalSpendingCents == 2000)
                #expect(result.usage.currentRequests == 500)
            }
        }
    }
}


// swiftlint:enable file_length type_body_length