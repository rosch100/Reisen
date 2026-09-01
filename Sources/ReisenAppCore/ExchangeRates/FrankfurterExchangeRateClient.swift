import Foundation
import ReisenDomain

public enum FrankfurterExchangeRateError: Error, Equatable, Sendable {
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed
    case emptyRates
}

/// Abruf täglicher Referenzkurse von api.frankfurter.dev (ECB u. a.).
public final class FrankfurterExchangeRateClient: ExchangeRateProviding, @unchecked Sendable {
    private let session: URLSession
    private let cache: ExchangeRateQuoteCache
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        cache: ExchangeRateQuoteCache = ExchangeRateQuoteCache(),
        baseURL: URL = URL(string: "https://api.frankfurter.dev/v1")!
    ) {
        self.session = session
        self.cache = cache
        self.baseURL = baseURL
    }

    public func latestQuote(base: String) async throws -> ExchangeRateQuote {
        let normalizedBase = base.uppercased()
        if let cached = cache.quote(forBase: normalizedBase), !cache.isStale(cached) {
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
            rates[code.uppercased()] = decimal(fromJSONNumber: value)
        }
        return ExchangeRateQuote(base: expectedBase, date: date, rates: rates)
    }

    /// Vermeidet Double→Decimal-Binärrauschen (JSON-Zahlen).
    private static func decimal(fromJSONNumber value: Double) -> Decimal {
        let formatted = String(format: "%.8f", value)
        return Decimal(string: formatted) ?? Decimal(value)
    }

    private struct Payload: Decodable {
        let amount: Double?
        let base: String?
        let date: String
        let rates: [String: Double]
    }
}

public final class ExchangeRateQuoteCache: @unchecked Sendable {
    private struct Entry {
        var quote: ExchangeRateQuote
        var fetchedAt: Date
    }

    private var stored: [String: Entry] = [:]
    private let lock = NSLock()
    public var maxAge: TimeInterval

    public init(maxAge: TimeInterval = 24 * 60 * 60) {
        self.maxAge = maxAge
    }

    public func quote(forBase base: String) -> ExchangeRateQuote? {
        lock.lock()
        defer { lock.unlock() }
        return stored[base.uppercased()]?.quote
    }

    public func store(_ quote: ExchangeRateQuote, fetchedAt: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        stored[quote.base] = Entry(quote: quote, fetchedAt: fetchedAt)
    }

    public func isStale(_ quote: ExchangeRateQuote, now: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = stored[quote.base] else { return true }
        if now.timeIntervalSince(entry.fetchedAt) > maxAge { return true }
        let calendar = Calendar(identifier: .gregorian)
        return calendar.startOfDay(for: quote.date) < calendar.startOfDay(for: now)
    }
}
