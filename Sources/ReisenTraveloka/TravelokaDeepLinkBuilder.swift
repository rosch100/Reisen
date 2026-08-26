import Foundation
import ReisenDomain
import ReisenProviders

public struct TravelokaDeepLinkBuilder: GapDeepLinkBuilding {
    public let providerID = ProviderID.traveloka

    public init() {}

    public func suggestions(for gap: GapContext) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        var links: [DeepLinkSuggestion] = []
        var issues: [DeepLinkIssue] = []

        let destination = gap.fromLocationTo ?? gap.toLocationFrom ?? gap.toLocationTo
        if let hotelURL = hotelSearchURL(destination: destination, checkIn: gap.gapStart, checkOut: gap.gapEnd) {
            links.append(DeepLinkSuggestion(title: "Hotel suchen (Traveloka)", url: hotelURL))
        } else {
            issues.append(.missingDestinationHint)
        }

        if let flightURL = flightSearchURL(
            from: gap.fromLocationTo ?? gap.fromLocationFrom,
            to: gap.toLocationFrom ?? gap.toLocationTo,
            date: gap.gapStart
        ) {
            links.append(DeepLinkSuggestion(title: "Flug suchen (Traveloka)", url: flightURL))
        } else {
            issues.append(.missingFromIATA)
        }

        if let activitiesURL = activitiesSearchURL(destination: destination) {
            links.append(DeepLinkSuggestion(title: "Erlebnis suchen (Traveloka)", url: activitiesURL))
        }

        return (links, issues)
    }

    private func hotelSearchURL(destination: String?, checkIn: Date, checkOut: Date) -> URL? {
        guard let destination, !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        var components = URLComponents(string: "\(TravelokaAPI.origin)/\(TravelokaAPI.routePrefix)/hotel/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: destination),
            URLQueryItem(name: "checkin", value: dayString(checkIn)),
            URLQueryItem(name: "checkout", value: dayString(checkOut)),
        ]
        return components?.url
    }

    private func flightSearchURL(from: String?, to: String?, date: Date) -> URL? {
        guard let fromCode = iata(from: from), let toCode = iata(from: to) else { return nil }
        var components = URLComponents(string: "\(TravelokaAPI.origin)/\(TravelokaAPI.routePrefix)/flight/fullsearch")
        components?.queryItems = [
            URLQueryItem(name: "ap", value: "\(fromCode).\(toCode)"),
            URLQueryItem(name: "dt", value: dayString(date)),
            URLQueryItem(name: "ps", value: "1.0.0"),
        ]
        return components?.url
    }

    private func activitiesSearchURL(destination: String?) -> URL? {
        var components = URLComponents(string: "\(TravelokaAPI.origin)/\(TravelokaAPI.routePrefix)/activities")
        if let destination, !destination.isEmpty {
            components?.queryItems = [URLQueryItem(name: "q", value: destination)]
        }
        return components?.url
    }

    private func dayString(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "dd-MM-yyyy"
        return df.string(from: date)
    }

    private func iata(from hint: String?) -> String? {
        guard let hint else { return nil }
        let pattern = #"\b[A-Z]{3}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let upper = hint.uppercased() as NSString
        let matches = regex.matches(in: hint.uppercased(), range: NSRange(location: 0, length: upper.length))
        guard let match = matches.first else { return nil }
        return upper.substring(with: match.range)
    }
}
