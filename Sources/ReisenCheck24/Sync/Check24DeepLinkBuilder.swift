import Foundation
import ReisenDomain
import ReisenProviders

public struct Check24DeepLinkBuilder: GapDeepLinkBuilding {
    public let providerID = ProviderID.check24

    public init() {}

    public func suggestions(for gap: GapContext) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        var issues: [DeepLinkIssue] = []
        var links: [DeepLinkSuggestion] = []

        let destinationHint = gap.fromLocationTo ?? gap.toLocationFrom ?? gap.toLocationTo
        do {
            let hotelURL = try makeHotelSearchURL(
                destinationHint: destinationHint,
                checkIn: gap.gapStart,
                checkOut: gap.gapEnd
            )
            links.append(DeepLinkSuggestion(title: "Hotel suchen (Check24)", url: hotelURL))
        } catch let issue as DeepLinkIssue {
            issues.append(issue)
        } catch {
            issues.append(.destinationIdNotDerivable)
        }

        do {
            // Zwischen-Transport: Abflug = letzter Ankunftsort, Ziel = Ort der nächsten Buchung.
            let flightURL = try makeFlightSearchURL(
                fromHint: gap.fromLocationTo ?? gap.fromLocationFrom,
                toHint: gap.toLocationFrom ?? gap.toLocationTo,
                date: gap.gapStart
            )
            links.append(DeepLinkSuggestion(title: "Flug suchen (Check24)", url: flightURL))
        } catch let issue as DeepLinkIssue {
            issues.append(issue)
        } catch {
            issues.append(.missingFromIATA)
        }

        return (links, issues)
    }

    private func makeHotelSearchURL(destinationHint: String?, checkIn: Date, checkOut: Date) throws -> URL {
        guard let destinationHint, !destinationHint.isEmpty else {
            throw DeepLinkIssue.missingDestinationHint
        }
        let parts = destinationHint.split(separator: "-")
        guard let last = parts.last, let destinationId = Int(last) else {
            throw DeepLinkIssue.destinationIdNotDerivable
        }
        let destinationName = parts.dropLast().joined(separator: "-")
        guard !destinationName.isEmpty else { throw DeepLinkIssue.destinationIdNotDerivable }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        let occupancyPath = "%5BA%7CA%5D"
        let urlString =
            "https://hotel.check24.de/search/\(destinationName)-\(destinationId)/\(df.string(from: checkIn))/\(df.string(from: checkOut))/\(occupancyPath)/"
        guard let url = URL(string: urlString) else { throw DeepLinkIssue.destinationIdNotDerivable }
        return url
    }

    private func makeFlightSearchURL(fromHint: String?, toHint: String?, date: Date) throws -> URL {
        guard let fromHint else { throw DeepLinkIssue.missingFromIATA }
        guard let toHint else { throw DeepLinkIssue.missingToIATA }
        guard let fromToken = flightSearchToken(from: fromHint) else { throw DeepLinkIssue.missingFromIATA }
        guard let toToken = flightSearchToken(from: toHint) else { throw DeepLinkIssue.missingToIATA }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        let urlString =
            "https://flug.check24.de/search?from_0=\(fromToken)-C&to_0=\(toToken)-C&date_0=\(df.string(from: date))&adt=1&class=EPBF"
        guard let url = URL(string: urlString) else { throw DeepLinkIssue.missingFromIATA }
        return url
    }

    private func flightSearchToken(from hint: String) -> String? {
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1) 3-letter IATA bevorzugen (z.B. "Frankfurt (FRA)" → FRA).
        //    Wichtig: Stadt-Namen wie "Yogyakarta" dürfen nicht fälschlich als "YOG" erkannt werden.
        let pattern = #"\b[A-Z]{3}\b"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let upper = trimmed.uppercased() as NSString
            let matches = regex.matches(in: trimmed.uppercased(), options: [], range: NSRange(location: 0, length: upper.length))
            if let match = matches.first {
                return upper.substring(with: match.range)
            }
        }

        // 2) Fallback: Stadtname-Token sanitizen, damit URL(string:) nicht an Leerzeichen scheitert.
        // Check24 scheint ein Token-Format zu akzeptieren; wenn es abgelehnt wird, kann der Nutzer manuell korrigieren.
        let upper = trimmed.uppercased()
        let sanitized = upper
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: #"[^A-Z0-9\-]"#, with: "", options: .regularExpression)
        guard !sanitized.isEmpty else { return nil }
        return sanitized
    }
}
