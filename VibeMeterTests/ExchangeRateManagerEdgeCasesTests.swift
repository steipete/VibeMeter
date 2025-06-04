import Foundation
@testable import VibeMeter
import XCTest

final class ExchangeRateManagerEdgeCasesTests: XCTestCase {
    private var mockURLSession: MockURLSession!
    private var exchangeRateManager: ExchangeRateManager!

    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        exchangeRateManager = ExchangeRateManager(urlSession: mockURLSession)
    }

    override func tearDown() {
        mockURLSession = nil
        exchangeRateManager = nil
        super.tearDown()
    }

    // MARK: - Edge Cases and Error Scenarios

    func testGetExchangeRates_EmptyRatesResponse() async {
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
        XCTAssertTrue(rates.isEmpty)
    }

    func testGetExchangeRates_MalformedHTTPResponse() async {
        // Given
        let mockRatesData = Data()
        mockURLSession.nextData = mockRatesData
        mockURLSession.nextResponse = URLResponse() // Not HTTPURLResponse

        // When
        let rates = await exchangeRateManager.getExchangeRates()

        // Then
        XCTAssertEqual(rates, exchangeRateManager.fallbackRates)
    }
}
