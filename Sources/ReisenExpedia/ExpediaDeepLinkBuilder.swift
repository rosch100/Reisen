import Foundation
import ReisenDomain

public struct ExpediaDeepLinkBuilder: GapDeepLinkBuilding {
    public let providerID = ProviderID.expedia

    public init() {}

    public func suggestions(for gap: GapContext) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        var bag = GapDeepLinkBag(providerID: providerID, kind: gap.kind)
        bag.add(
            .hotel,
            url: hotelSearchURL(
                destination: gap.destinationHint,
                checkIn: gap.gapStart,
                checkOut: gap.gapEnd
            ),
            missing: .missingDestinationHint
        )
        bag.add(
            .carRental,
            url: carSearchURL(
                destination: gap.destinationHint,
                start: gap.gapStart,
                end: gap.gapEnd
            ),
            missing: .missingDestinationHint
        )
        return bag.result
    }

    private func hotelSearchURL(destination: String?, checkIn: Date, checkOut: Date) -> URL? {
        guard let destination else { return nil }
        var components = URLComponents(string: "\(ExpediaAPI.origin)/Hotel-Search")
        components?.queryItems = [
            URLQueryItem(name: "destination", value: destination),
            URLQueryItem(name: "startDate", value: GapDeepLinkText.posixDay(checkIn)),
            URLQueryItem(name: "endDate", value: GapDeepLinkText.posixDay(checkOut)),
            URLQueryItem(name: "rooms", value: "1"),
            URLQueryItem(name: "adults", value: GapDeepLinkText.defaultLodgingAdults),
        ]
        return components?.url
    }

    private func carSearchURL(destination: String?, start: Date, end: Date) -> URL? {
        guard let destination else { return nil }
        // HAR uses dd.MM.yyyy; times only when Gap has concrete wall times (non-midnight pair).
        let dayFormat = DateFormatter()
        dayFormat.locale = Locale(identifier: "en_US_POSIX")
        dayFormat.timeZone = TimeZone(secondsFromGMT: 0)
        dayFormat.dateFormat = "dd.MM.yyyy"

        var items: [URLQueryItem] = [
            URLQueryItem(name: "locn", value: destination),
            URLQueryItem(name: "date1", value: dayFormat.string(from: start)),
            URLQueryItem(name: "date2", value: dayFormat.string(from: end)),
        ]
        if let times = carTimes(start: start, end: end) {
            items.append(URLQueryItem(name: "time1", value: times.0))
            items.append(URLQueryItem(name: "time2", value: times.1))
        } else {
            // Plan: without concrete times, no Car link.
            return nil
        }
        var components = URLComponents(string: "\(ExpediaAPI.origin)/carsearch/details")
        components?.queryItems = items
        return components?.url
    }

    private func carTimes(start: Date, end: Date) -> (String, String)? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let s = cal.dateComponents([.hour, .minute], from: start)
        let e = cal.dateComponents([.hour, .minute], from: end)
        let startMinutes = (s.hour ?? 0) * 60 + (s.minute ?? 0)
        let endMinutes = (e.hour ?? 0) * 60 + (e.minute ?? 0)
        // Treat pure date anchors (00:00 UTC) as lacking concrete times.
        if startMinutes == 0 && endMinutes == 0 {
            return nil
        }
        return (formatExpediaTime(startMinutes), formatExpediaTime(endMinutes))
    }

    private func formatExpediaTime(_ minutes: Int) -> String {
        var hour = minutes / 60
        let minute = minutes % 60
        let ampm: String
        if hour >= 12 {
            ampm = "PM"
            if hour > 12 { hour -= 12 }
        } else {
            ampm = "AM"
            if hour == 0 { hour = 12 }
        }
        return String(format: "%d%02d%@", hour, minute, ampm)
    }
}
