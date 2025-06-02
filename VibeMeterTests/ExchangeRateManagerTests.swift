@testable import VibeMeter
import XCTest

@MainActor
class ExchangeRateManagerTests: XCTestCase, @unchecked Sendable {
    var exchangeRateManager: RealExchangeRateManager!
    var mockURLSession: MockURLSession!
    var testUserDefaults: UserDefaults!
    let testSuiteName = "com.vibemeter.tests.ExchangeRateManagerTests"

    override func setUp() {
        super.setUp()
        let suite = UserDefaults(suiteName: testSuiteName)
        suite?.removePersistentDomain(forName: testSuiteName)
        
        MainActor.assumeIsolated {
            testUserDefaults = suite
            mockURLSession = MockURLSession()
            exchangeRateManager = RealExchangeRateManager(userDefaults: testUserDefaults, session: mockURLSession)
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            testUserDefaults.removePersistentDomain(forName: testSuiteName)
            testUserDefaults = nil
            exchangeRateManager = nil
            mockURLSession = nil
        }
        super.tearDown()
    }

    func testSupportedCurrencies() {
        let expectedCurrencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "PHP"]
        XCTAssertEqual(
            exchangeRateManager.supportedCurrencies.count,
            expectedCurrencies.count,
            "Should have the correct number of supported currencies."
        )
        for expectedCurrency in expectedCurrencies {
            XCTAssertTrue(
                exchangeRateManager.supportedCurrencies.contains(expectedCurrency),
                "\(expectedCurrency) should be a supported currency."
            )
        }
    }

    func testGetCurrencySymbol() {
        XCTAssertEqual(RealExchangeRateManager.getSymbol(for: "USD"), "$")
        XCTAssertEqual(RealExchangeRateManager.getSymbol(for: "EUR"), "€")
        XCTAssertEqual(RealExchangeRateManager.getSymbol(for: "GBP"), "£")
        XCTAssertEqual(RealExchangeRateManager.getSymbol(for: "JPY"), "¥")
        XCTAssertEqual(RealExchangeRateManager.getSymbol(for: "CAD"), "CA$")
        XCTAssertEqual(RealExchangeRateManager.getSymbol(for: "AUD"), "A$")
        XCTAssertEqual(RealExchangeRateManager.getSymbol(for: "CHF"), "CHF")
        XCTAssertEqual(RealExchangeRateManager.getSymbol(for: "CNY"), "CN¥")
        XCTAssertEqual(RealExchangeRateManager.getSymbol(for: "INR"), "₹")
        XCTAssertEqual(RealExchangeRateManager.getSymbol(for: "PHP"), "₱")
        XCTAssertEqual(RealExchangeRateManager.getSymbol(for: "XYZ"), "XYZ ") // Unknown currency
    }

    func testFetchExchangeRatesSuccessfully() async {
        let mockAPIResponse = FrankfurterResponse(rates: ["EUR": 0.9482, "GBP": 0.8233])
        let mockData = (try? JSONEncoder().encode(mockAPIResponse)) ?? Data()

        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.frankfurter.app/latest?from=USD&to=EUR,GBP,JPY,CAD,AUD,CHF,CNY,INR,PHP")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let rates = await exchangeRateManager.fetchExchangeRates()
        XCTAssertNotNil(rates, "Rates should not be nil on successful fetch.")
        XCTAssertEqual(rates?["EUR"], 0.9482)
        XCTAssertEqual(rates?["GBP"], 0.8233)
        XCTAssertEqual(rates?["USD"], 1.0, "USD rate should be added and be 1.0")
        XCTAssertNotNil(
            testUserDefaults.dictionary(forKey: RealExchangeRateManager.Keys.cachedExchangeRates),
            "Rates should be cached."
        )
        XCTAssertNotNil(
            testUserDefaults.object(forKey: RealExchangeRateManager.Keys.lastExchangeRateFetchTimestamp),
            "Timestamp should be cached."
        )
    }

    func testFetchExchangeRatesWithNetworkError() async {
        mockURLSession.nextError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        let rates = await exchangeRateManager.fetchExchangeRates()
        XCTAssertNil(rates, "Rates should be nil on network error.")
        let cachedRates = testUserDefaults.dictionary(forKey: RealExchangeRateManager.Keys.cachedExchangeRates)
        XCTAssertNil(cachedRates, "Cache should not be updated on network error.")
    }

    func testFetchExchangeRatesWithInvalidJSON() async {
        let invalidJSONData = Data("{\"invalid_json\": \"not the expected structure\"}".utf8)
        mockURLSession.nextData = invalidJSONData
        mockURLSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.frankfurter.app/latest?from=USD&to=EUR,GBP,JPY,CAD,AUD,CHF,CNY,INR,PHP")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let rates = await exchangeRateManager.fetchExchangeRates()
        XCTAssertNil(rates, "Rates should be nil with invalid JSON that doesn't match FrankfurterResponse.")
    }

    func testFetchExchangeRatesWithNon200Status() async {
        mockURLSession.nextData = Data() // Some data might be present even on error
        mockURLSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.frankfurter.app/latest?from=USD&to=EUR,GBP,JPY,CAD,AUD,CHF,CNY,INR,PHP")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        let rates = await exchangeRateManager.fetchExchangeRates()
        XCTAssertNil(rates, "Rates should be nil on non-200 HTTP status.")
    }

    func testGetRatesUsesCacheWhenValid() async {
        let cachedRatesData = ["EUR": 0.95, "GBP": 0.85, "USD": 1.0]
        testUserDefaults.set(cachedRatesData, forKey: RealExchangeRateManager.Keys.cachedExchangeRates)
        let recentTimestamp = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        testUserDefaults.set(recentTimestamp, forKey: RealExchangeRateManager.Keys.lastExchangeRateFetchTimestamp)

        let rates = await exchangeRateManager.getRates()
        XCTAssertEqual(rates, cachedRatesData, "Should return cached rates when valid.")
        XCTAssertEqual(mockURLSession.dataTaskCallCount, 0, "Should not fetch new rates if cache is valid.")
    }

    func testGetRatesFetchesWhenCacheExpired() async {
        let oldCachedRates = ["EUR": 0.90, "USD": 1.0]
        testUserDefaults.set(oldCachedRates, forKey: RealExchangeRateManager.Keys.cachedExchangeRates)
        let expiredTimestamp = Calendar.current.date(byAdding: .hour, value: -25, to: Date())!
        testUserDefaults.set(expiredTimestamp, forKey: RealExchangeRateManager.Keys.lastExchangeRateFetchTimestamp)

        let freshAPIRates = FrankfurterResponse(rates: ["EUR": 0.99, "JPY": 150.0])
        let mockData = (try? JSONEncoder().encode(freshAPIRates)) ?? Data()
        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.frankfurter.app/latest?from=USD&to=EUR,GBP,JPY,CAD,AUD,CHF,CNY,INR,PHP")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let rates = await exchangeRateManager.getRates()
        var expectedFetchedRates = freshAPIRates.rates
        expectedFetchedRates["USD"] = 1.0 // fetchExchangeRates adds USD
        XCTAssertEqual(rates, expectedFetchedRates, "Should fetch and return new rates when cache is expired.")
        XCTAssertEqual(mockURLSession.dataTaskCallCount, 1, "Should have fetched new rates.")
    }

    func testGetRatesUsesFallbackWhenFetchFailsAndCacheInvalid() async {
        testUserDefaults.removeObject(forKey: RealExchangeRateManager.Keys.cachedExchangeRates)
        testUserDefaults.removeObject(forKey: RealExchangeRateManager.Keys.lastExchangeRateFetchTimestamp)

        mockURLSession.nextError = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost, userInfo: nil)

        let rates = await exchangeRateManager.getRates()
        XCTAssertEqual(
            rates,
            exchangeRateManager.fallbackRates,
            "Should return fallback rates when fetch fails and cache is invalid."
        )
        XCTAssertEqual(mockURLSession.dataTaskCallCount, 1, "Should have attempted to fetch new rates.")
    }

    func testGetRatesUsesFallbackWhenFetchReturnsNilAndCacheInvalid() async {
        testUserDefaults.removeObject(forKey: RealExchangeRateManager.Keys.cachedExchangeRates)
        testUserDefaults.removeObject(forKey: RealExchangeRateManager.Keys.lastExchangeRateFetchTimestamp)

        mockURLSession.nextData = Data("{\"corrupt\":true}".utf8)
        mockURLSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.frankfurter.app/latest?from=USD&to=EUR,GBP,JPY,CAD,AUD,CHF,CNY,INR,PHP")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let rates = await exchangeRateManager.getRates()
        XCTAssertEqual(
            rates,
            exchangeRateManager.fallbackRates,
            "Should return fallback rates when fetch returns nil and cache is invalid."
        )
        XCTAssertEqual(mockURLSession.dataTaskCallCount, 1, "Should have attempted to fetch new rates.")
    }

    func testConvertAmount() async {
        let currentRates = ["EUR": 0.9, "GBP": 0.8, "USD": 1.0]
        let convertedToEUR = exchangeRateManager.convert(100.0, from: "USD", to: "EUR", rates: currentRates)
        XCTAssertEqual(convertedToEUR!, 90.0, accuracy: 0.001)

        let convertedToGBP = exchangeRateManager.convert(100.0, from: "USD", to: "GBP", rates: currentRates)
        XCTAssertEqual(convertedToGBP!, 80.0, accuracy: 0.001)

        let convertedUSDToUSD = exchangeRateManager.convert(100.0, from: "USD", to: "USD", rates: currentRates)
        XCTAssertEqual(convertedUSDToUSD!, 100.0, accuracy: 0.001)

        let convertEURToUSD = exchangeRateManager.convert(90.0, from: "EUR", to: "USD", rates: currentRates)
        XCTAssertEqual(convertEURToUSD!, 100.0, accuracy: 0.001)

        let convertGBPToEUR = exchangeRateManager.convert(80.0, from: "GBP", to: "EUR", rates: currentRates)
        XCTAssertEqual(convertGBPToEUR!, 90.0, accuracy: 0.001)

        let convertedToXYZ = exchangeRateManager.convert(100.0, from: "USD", to: "XYZ", rates: currentRates)
        XCTAssertNil(convertedToXYZ, "Conversion should be nil if target rate is unavailable.")

        let convertedFromXYZ = exchangeRateManager.convert(100.0, from: "XYZ", to: "USD", rates: currentRates)
        XCTAssertNil(convertedFromXYZ, "Conversion should be nil if source rate is unavailable for non-USD to USD.")

        let convertedWithNilRates = exchangeRateManager.convert(100.0, from: "USD", to: "EUR", rates: nil)
        XCTAssertNil(convertedWithNilRates, "Conversion should be nil if rates dictionary is nil.")

        let convertedWithEmptyRates = exchangeRateManager.convert(100.0, from: "USD", to: "EUR", rates: [:])
        XCTAssertNil(convertedWithEmptyRates, "Conversion should be nil if rates dictionary is empty.")

        let ratesWithZero = ["EUR": 0.0, "USD": 1.0]
        let convertWithZeroRate = exchangeRateManager.convert(100.0, from: "EUR", to: "USD", rates: ratesWithZero)
        XCTAssertNil(convertWithZeroRate, "Conversion should be nil if source rate is zero.")
    }
}
