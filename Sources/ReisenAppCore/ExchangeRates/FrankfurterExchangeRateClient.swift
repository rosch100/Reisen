import Foundation
import ReisenDomain

public enum FrankfurterExchangeRateError: Error, Equatable, Sendable {
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed
    case emptyRates
    case baseMismatch(expected: String, actual: String)
}

/// Abruf täglicher Referenzkurse von api.frankfurter.dev (ECB u. a.).
public final class FrankfurterExchangeRateClient: ExchangeRateProviding, @unchecked Sendable {
    private let session: URLSession
    private let cache: ExchangeRateQuoteCache
    private let baseURL: URL

    public static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }

    public init(
        session: URLSession = FrankfurterExchangeRateClient.makeDefaultSession(),
        cache: ExchangeRateQuoteCache = ExchangeRateQuoteCache(),
        baseURL: URL = URL(string: "https://api.frankfurter.dev/v1")!
    ) {
        self.session = session
        self.cache = cache
        self.baseURL = baseURL
    }

    public func latestQuote(base: String) async throws -> ExchangeRateQuote {
        let normalizedBase = CurrencyCode.normalize(base)
        if let cached = cache.freshQuote(forBase: normalizedBase) {
            return cached
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("latest"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "from", value: normalizedBase)]
        guard let url = components.url else { throw FrankfurterExchangeRateError.invalidResponse }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw FrankfurterExchangeRateError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FrankfurterExchangeRateError.httpStatus(http.statusCode)
        }

        let quote = try Self.decodeQuote(data: data, expectedBase: normalizedBase)
        cache.store(quote)
        return quote
    }

    public static func decodeQuote(data: Data, expectedBase: String) throws -> ExchangeRateQuote {
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw FrankfurterExchangeRateError.decodingFailed
        }
        guard !payload.rates.isEmpty else { throw FrankfurterExchangeRateError.emptyRates }

        let expected = CurrencyCode.normalize(expectedBase)
        if let actual = payload.base.map(CurrencyCode.normalize),
           !actual.isEmpty,
           actual != expected {
            throw FrankfurterExchangeRateError.baseMismatch(expected: expected, actual: actual)
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: payload.date) else {
            throw FrankfurterExchangeRateError.decodingFailed
        }

        var rates: [String: Decimal] = [:]
        for (code, value) in payload.rates {
            guard let decimal = DecimalJSON.parse(value) else {
                throw FrankfurterExchangeRateError.decodingFailed
            }
            rates[CurrencyCode.normalize(code)] = decimal
        }
        return ExchangeRateQuote(base: expected, date: date, rates: rates)
    }

    private struct Payload: Decodable {
        let amount: Double?
        let base: String?
        let date: String
        let rates: [String: Double]
    }
}
