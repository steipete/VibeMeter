import Foundation
import Testing
@testable import VibeMeter

// MARK: - Performance Benchmarks

@Suite("Performance Benchmarks", .tags(.performance))
struct PerformanceBenchmarks {
    
    // MARK: - Currency Conversion Performance
    
    @Suite("Currency Conversion", .tags(.currency))
    struct CurrencyConversion {
        
        @Test("Bulk currency conversion performance", .timeLimit(.minutes(1)))
        @MainActor
        func bulkCurrencyConversionPerformance() {
            // Given
            let amounts = Array(stride(from: 0.01, through: 10000.0, by: 0.01))
            let exchangeRates = [
                "EUR": 0.92,
                "GBP": 0.82,
                "JPY": 110.0,
                "AUD": 1.35,
                "CAD": 1.25
            ]
            let currencies = ["EUR", "GBP", "JPY", "AUD", "CAD"]
            
            // When - Convert each amount to each currency
            let startTime = Date()
            
            for amount in amounts {
                for currency in currencies {
                    _ = CurrencyConversionHelper.convert(
                        amount: amount,
                        rate: exchangeRates[currency]
                    )
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Then
            print("Converted \(amounts.count * currencies.count) values in \(duration) seconds")
            #expect(duration < 10.0) // Should complete in under 10 seconds
        }
        
        @Test("Currency formatting performance", .timeLimit(.minutes(1)))
        @MainActor
        func currencyFormattingPerformance() {
            // Given
            let amounts = (1...10000).map { Double($0) * 0.99 }
            let symbols = ["$", "€", "£", "¥", "A$", "C$"]
            let locales = [
                Locale(identifier: "en_US"),
                Locale(identifier: "de_DE"),
                Locale(identifier: "ja_JP"),
                Locale(identifier: "fr_FR")
            ]
            
            // When
            let startTime = Date()
            
            for amount in amounts {
                for symbol in symbols {
                    for locale in locales {
                        _ = CurrencyConversionHelper.formatAmount(
                            amount,
                            currencySymbol: symbol,
                            locale: locale
                        )
                    }
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Then
            print("Formatted \(amounts.count * symbols.count * locales.count) values in \(duration) seconds")
            #expect(duration < 15.0) // Should complete in under 15 seconds
        }
    }
    
    // MARK: - String Manipulation Performance
    
    @Suite("String Operations", .tags(.unit))
    struct StringOperations {
        
        @Test("String truncation performance", .timeLimit(.minutes(1)))
        func stringTruncationPerformance() {
            // Given
            let testStrings = (1...1000).map { index in
                String(repeating: "Test string \(index) with some content. ", count: index)
            }
            let lengths = [10, 20, 50, 100, 200]
            
            // When
            let startTime = Date()
            
            for string in testStrings {
                for length in lengths {
                    _ = string.truncate(length: length)
                    _ = string.truncated(to: length)
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Then
            print("Truncated \(testStrings.count * lengths.count * 2) strings in \(duration) seconds")
            #expect(duration < 5.0) // Should complete in under 5 seconds
        }
        
        @Test("Menu bar string formatting performance", .timeLimit(.minutes(1)))
        func menuBarStringFormattingPerformance() {
            // Given
            let amounts = stride(from: 0.0, through: 999999.99, by: 100.0).map { $0 }
            let currencies = ["$", "€", "£", "¥"]
            
            // When
            let startTime = Date()
            
            for amount in amounts {
                for currency in currencies {
                    // Format the string for menu bar display
                    let formattedAmount = Int(amount)
                    _ = "\(currency)\(formattedAmount)"
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Then
            print("Formatted \(amounts.count * currencies.count) menu bar strings in \(duration) seconds")
            #expect(duration < 2.0) // Should complete in under 2 seconds
        }
    }
    
    // MARK: - Data Processing Performance
    
    @Suite("Data Processing", .tags(.integration))
    struct DataProcessing {
        
        @Test("Multi-provider data aggregation", .timeLimit(.minutes(1)))
        @MainActor
        func multiProviderDataAggregation() async {
            // Given
            let spendingData = MultiProviderSpendingData()
            let _: [ServiceProvider] = [.cursor]
            let months = 12
            let itemsPerMonth = 50
            
            // Create test data
            var invoices: [ProviderMonthlyInvoice] = []
            for month in 1...months {
                let items = (1...itemsPerMonth).map { index in
                    ProviderInvoiceItem(
                        cents: 100 * index,
                        description: "Item \(index)",
                        provider: .cursor
                    )
                }
                
                let invoice = ProviderMonthlyInvoice(
                    items: items,
                    pricingDescription: nil,
                    provider: .cursor,
                    month: month,
                    year: 2024
                )
                invoices.append(invoice)
            }
            
            // When
            let startTime = Date()
            
            for invoice in invoices {
                spendingData.updateSpending(
                    for: invoice.provider,
                    from: invoice,
                    rates: ["EUR": 0.92],
                    targetCurrency: "EUR"
                )
            }
            
            // Calculate totals
            for _ in 1...1000 {
                _ = spendingData.totalSpendingConverted(to: "EUR", rates: ["EUR": 0.92])
                _ = spendingData.totalSpendingConverted(to: "USD", rates: [:])
            }
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Then
            print("Processed \(invoices.count) invoices with \(itemsPerMonth) items each in \(duration) seconds")
            #expect(duration < 5.0) // Should complete in under 5 seconds
        }
        
        @Test("Provider connection status updates", .timeLimit(.minutes(1)))
        func providerConnectionStatusUpdates() {
            // Given
            let statusTransitions: [(from: ProviderConnectionStatus, to: ProviderConnectionStatus)] = [
                (.disconnected, .connecting),
                (.connecting, .connected),
                (.connected, .syncing),
                (.syncing, .connected),
                (.connected, .error(message: "Test error")),
                (.error(message: "Test error"), .connecting),
                (.connecting, .rateLimited(until: Date())),
                (.rateLimited(until: nil), .connected)
            ]
            
            // When
            let startTime = Date()
            
            for _ in 1...10000 {
                for (fromStatus, toStatus) in statusTransitions {
                    // Simulate status change checks
                    _ = fromStatus.isActive
                    _ = toStatus.isActive
                    _ = fromStatus.displayColor
                    _ = toStatus.displayColor
                    _ = fromStatus.iconName
                    _ = toStatus.iconName
                    _ = fromStatus.description
                    _ = toStatus.description
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Then
            print("Processed \(10000 * statusTransitions.count) status transitions in \(duration) seconds")
            #expect(duration < 3.0) // Should complete in under 3 seconds
        }
    }
    
    // MARK: - Menu Bar Updates Performance
    
    @Suite("Menu Bar Updates", .tags(.ui))
    @MainActor
    struct MenuBarUpdates {
        
        @Test("Gauge animation calculations", .timeLimit(.minutes(1)))
        func gaugeAnimationCalculations() {
            // Given
            let manager = MenuBarStateManager()
            let progressValues = stride(from: 0.0, through: 1.0, by: 0.001).map { $0 }
            
            // When
            let startTime = Date()
            
            // Simulate rapid state changes
            for progress in progressValues {
                manager.setState(.data(value: progress))
                manager.updateAnimation()
                _ = manager.animatedGaugeValue
            }
            
            // Test easing function performance
            for _ in 1...100000 {
                for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                    _ = manager.easeInOut(progress)
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Then
            print("Calculated \(progressValues.count + 1100000) animation values in \(duration) seconds")
            #expect(duration < 5.0) // Should complete in under 5 seconds
        }
        
        @Test("Menu text generation performance", .timeLimit(.minutes(1)))
        func menuTextGenerationPerformance() {
            // Given
            let amounts = stride(from: 0.0, through: 999999.99, by: 1000.0).map { $0 }
            let limits = [100.0, 200.0, 500.0, 1000.0, 5000.0]
            let currencies = ["$", "€", "£", "¥"]
            
            // When
            let startTime = Date()
            
            for amount in amounts {
                for limit in limits {
                    for currency in currencies {
                        // Simulate menu text generation
                        let percentage = Int((amount / limit) * 100)
                        _ = "\(currency)\(Int(amount)) (\(percentage)%)"
                        
                        // Check if warning needed
                        _ = amount > (limit * 0.75)
                        _ = amount > (limit * 0.9)
                        _ = amount > limit
                    }
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Then
            print("Generated \(amounts.count * limits.count * currencies.count) menu texts in \(duration) seconds")
            #expect(duration < 2.0) // Should complete in under 2 seconds
        }
    }
}