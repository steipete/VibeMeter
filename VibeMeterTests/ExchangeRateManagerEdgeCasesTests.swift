import Foundation
@testable import VibeMeter
import Testing

@Suite("ExchangeRateManagerEdgeCasesTests")
struct ExchangeRateManagerEdgeCasesTests {
    private let mockURLSession: MockURLSession
    private let exchangeRateManager: ExchangeRateManager
    // MARK: - Edge Cases and Error Scenarios

    @Test("get exchange rates  empty rates response")

    func getExchangeRates_EmptyRatesResponse() async {
        // Given
        let mockRatesData = Data("""
        {
            "base": "USD",
            "date": "2023-12-01",
            "rates": {}
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.frankfurter.app/latest")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockRatesData
        mockURLSession.nextResponse = mockResponse

        // When
        let rates = await exchangeRateManager.getExchangeRates()

        // Then
        #expect(rates.isEmpty == true)

    func getExchangeRates_MalformedHTTPResponse() async {
        // Given
        let mockRatesData = Data()
        mockURLSession.nextData = mockRatesData
        mockURLSession.nextResponse = URLResponse() // Not HTTPURLResponse

        // When
        let rates = await exchangeRateManager.getExchangeRates()

        // Then
        #expect(rates == exchangeRateManager.fallbackRates)
    }
}
