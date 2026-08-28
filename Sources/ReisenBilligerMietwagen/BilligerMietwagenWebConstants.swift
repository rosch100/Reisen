import Foundation
import ReisenProviders

/// Booking-/Catalog-URLs. Auth-Surfaces: `BilligerMietwagenAuthConstants`.
enum BilligerMietwagenWebConstants {
    private static let origin = BilligerMietwagenAuthConstants.origin
    static let bookingsPathSegment = "bookings"
    private static let accountBookingsPath = BilligerMietwagenAuthConstants.accountBookingsPath

    /// Catalog-List-Endpoint als ein Literal (SSOT + Private Binary-Isolation-Marker).
    static let bookingsAPIURL = URL(string: "https://consumer-api.floyt.com/useraccount/v1/bookings")!
    private static let webBookingAPIPathPrefix = "/useraccount/v1/web/bookings"

    private static let activityStatusActive = "active"
    private static let activityStatusInactive = "inactive"
    private static let sortByPickupDate = "PickupDate"
    private static let sortByDropOffDate = "DropOffDate"
    private static let sortOrderAsc = "asc"
    private static let sortOrderDesc = "desc"

    /// Seitengröße der SPA-Listenabfrage (Pagination über `page` / `_pointers`).
    static let bookingListPageLimit = 10

    /// Sicherheitsgrenze gegen Endlosschleifen bei kaputten `_pointers`.
    static let bookingListMaxPages = 100

    static var catalogBookingsURL: URL {
        BilligerMietwagenAuthConstants.portalURL(accountBookingsPath)
    }

    /// Referer für Catalog/Detail nach Login (SPA „Meine Buchungen“) — SSOT `sessionReferer`.
    static var catalogReferer: String {
        BilligerMietwagenAuthConstants.sessionReferer
    }

    enum CatalogList: CaseIterable, Sendable {
        case active
        case inactive

        func url(page: Int) -> URL {
            switch self {
            case .active:
                return bookingsQueryURL(
                    activityStatus: activityStatusActive,
                    sortBy: sortByPickupDate,
                    sortOrder: sortOrderAsc,
                    page: page
                )
            case .inactive:
                return bookingsQueryURL(
                    activityStatus: activityStatusInactive,
                    sortBy: sortByDropOffDate,
                    sortOrder: sortOrderDesc,
                    page: page
                )
            }
        }
    }

    private static func bookingsQueryURL(
        activityStatus: String,
        sortBy: String,
        sortOrder: String,
        page: Int
    ) -> URL {
        guard var components = URLComponents(
            url: bookingsAPIURL,
            resolvingAgainstBaseURL: false
        ) else {
            preconditionFailure("Ungültige billiger-mietwagen Bookings-API-URL")
        }
        components.queryItems = [
            URLQueryItem(name: "activity_status", value: activityStatus),
            URLQueryItem(name: "sort_by", value: sortBy),
            URLQueryItem(name: "sort_order", value: sortOrder),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(bookingListPageLimit)),
        ]
        guard let url = components.url else {
            preconditionFailure("Ungültige billiger-mietwagen Bookings-Query-URL")
        }
        return url
    }

    static func bookingDetailURL(id: String) -> URL {
        BilligerMietwagenAuthConstants.consumerURL("\(webBookingAPIPathPrefix)/\(id)")
    }

    static func bookingPageURL(id: String) -> String {
        "\(origin)\(accountBookingsPath)/\(id)"
    }

    static func bookingID(from externalUrl: String) -> String? {
        guard let url = URL(string: externalUrl),
              let host = url.host,
              BilligerMietwagenAuthConstants.isPortalHost(host)
        else {
            return nil
        }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let bookingsIdx = parts.firstIndex(of: bookingsPathSegment),
              bookingsIdx + 1 < parts.count
        else {
            return nil
        }
        let id = parts[bookingsIdx + 1]
        return id.isEmpty ? nil : id
    }
}
