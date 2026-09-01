import Foundation
import Testing
import ReisenDomain
import ReisenAppCore

@Test func frankfurterDecode_mapsRatesToDecimal() throws {
    let json = """
    {"amount":1.0,"base":"EUR","date":"2026-08-31","rates":{"USD":1.1596,"GBP":0.85648}}
    """.data(using: .utf8)!
    let quote = try FrankfurterExchangeRateClient.decodeQuote(data: json, expectedBase: "EUR")
    #expect(quote.base == "EUR")
    #expect(quote.rates["USD"] == Decimal(string: "1.1596"))
    #expect(quote.rates["GBP"] == Decimal(string: "0.85648"))
}

@Test func frankfurterDecode_emptyRates_throws() {
    let json = #"{"amount":1.0,"base":"EUR","date":"2026-08-31","rates":{}}"#.data(using: .utf8)!
    #expect(throws: FrankfurterExchangeRateError.emptyRates) {
        try FrankfurterExchangeRateClient.decodeQuote(data: json, expectedBase: "EUR")
    }
}

@Test func frankfurterCache_hitSkipsStaleFalse() {
    let cache = ExchangeRateQuoteCache(maxAge: 3600)
    let quote = ExchangeRateQuote(base: "EUR", date: Date(), rates: ["USD": 1])
    cache.store(quote, fetchedAt: Date())
    #expect(cache.isStale(quote) == false)
    #expect(cache.quote(forBase: "EUR")?.rates["USD"] == 1)
}

@Suite(.serialized)
struct FrankfurterHTTPClientTests {
    private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
        nonisolated(unsafe) static var requestCount = 0
        nonisolated(unsafe) static var statusCode = 200
        nonisolated(unsafe) static var body = Data()

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            Self.requestCount += 1
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: Self.statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Self.body)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    private func makeClient() -> FrankfurterExchangeRateClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return FrankfurterExchangeRateClient(
            session: URLSession(configuration: config),
            cache: ExchangeRateQuoteCache(maxAge: 3600)
        )
    }

    @Test func fetchesViaSessionAndCaches() async throws {
        StubURLProtocol.requestCount = 0
        StubURLProtocol.statusCode = 200
        StubURLProtocol.body = Data(
            #"{"amount":1.0,"base":"EUR","date":"2026-08-31","rates":{"USD":1.1}}"#.utf8
        )
        let client = makeClient()
        let first = try await client.latestQuote(base: "EUR")
        let second = try await client.latestQuote(base: "EUR")
        #expect(first.rates["USD"] == Decimal(string: "1.10000000"))
        #expect(second.rates["USD"] == first.rates["USD"])
        #expect(StubURLProtocol.requestCount == 1)
    }

    @Test func httpErrorIsTyped() async {
        StubURLProtocol.requestCount = 0
        StubURLProtocol.statusCode = 503
        StubURLProtocol.body = Data()
        let client = makeClient()
        do {
            _ = try await client.latestQuote(base: "EUR")
            Issue.record("expected http error")
        } catch let error as FrankfurterExchangeRateError {
            #expect(error == .httpStatus(503))
        } catch {
            Issue.record("unexpected \(error)")
        }
    }
}
