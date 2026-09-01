import Foundation
import ReisenDomain

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

    /// Atomar: liefert nur ein Cache-Hit, der zum selben Zeitpunkt noch frisch ist.
    public func freshQuote(forBase base: String, now: Date = Date()) -> ExchangeRateQuote? {
        lock.lock()
        defer { lock.unlock() }
        let key = CurrencyCode.normalize(base)
        guard let entry = stored[key] else { return nil }
        if isExpired(entry, now: now) { return nil }
        return entry.quote
    }

    public func store(_ quote: ExchangeRateQuote, fetchedAt: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        stored[CurrencyCode.normalize(quote.base)] = Entry(quote: quote, fetchedAt: fetchedAt)
    }

    private func isExpired(_ entry: Entry, now: Date) -> Bool {
        now.timeIntervalSince(entry.fetchedAt) > maxAge
    }
}
