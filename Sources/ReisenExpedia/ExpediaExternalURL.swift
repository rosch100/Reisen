import Foundation

enum ExpediaExternalURL {
    struct Parts: Equatable, Sendable {
        var tripViewId: String
        var tripItemId: String
    }

    static func parts(from urlString: String?) -> Parts? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        let path = url.path
        guard let tripsRange = path.range(of: "/trips/") else { return nil }
        let afterTrips = path[tripsRange.upperBound...]
        let segments = afterTrips.split(separator: "/").map(String.init)
        guard segments.count >= 3, segments[0].hasPrefix("egti-"), segments[1] == "details" else {
            return nil
        }
        return Parts(tripViewId: segments[0], tripItemId: segments[2])
    }

    /// Lodging `BookingServicingManageQuery.tripId` is the UUID segment inside the encoded trip item id
    /// (`base64("uuid;orderLine…;eg:property:…")`), not the `egti-*` trip view id.
    static func lodgingServicingTripId(fromEncodedTripItemId encoded: String) -> String? {
        let padded: String = {
            let rem = encoded.count % 4
            guard rem != 0 else { return encoded }
            return encoded + String(repeating: "=", count: 4 - rem)
        }()
        guard let data = Data(base64Encoded: padded, options: [.ignoreUnknownCharacters]),
              let decoded = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        let head = decoded.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true).first
            .map(String.init)
        guard let head, head.count == 36, head.contains("-") else { return nil }
        return head
    }

    static func detailURL(tripViewId: String, tripItemId: String) -> String? {
        guard var components = URLComponents(string: ExpediaAPI.origin) else { return nil }
        components.path = "/trips/\(tripViewId)/details/\(tripItemId)"
        components.query = nil
        components.fragment = nil
        return components.string
    }

    static func manageBookingURL(tripViewId: String, tripItemId: String) -> String? {
        guard let detail = detailURL(tripViewId: tripViewId, tripItemId: tripItemId) else { return nil }
        return appendingManageBooking(to: detail)
    }

    /// Appends `/manage-booking` via path segments (preserves query/fragment; idempotent).
    static func appendingManageBooking(to urlString: String) -> String? {
        guard var components = URLComponents(string: urlString) else { return nil }
        let path = components.path
        if path.lowercased().contains("/manage-booking") {
            return urlString
        }
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        components.path = trimmed.isEmpty ? "/manage-booking" : "\(trimmed)/manage-booking"
        return components.string
    }
}
