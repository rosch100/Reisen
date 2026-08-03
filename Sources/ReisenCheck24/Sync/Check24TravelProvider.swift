import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

@MainActor
public final class Check24TravelProvider: TravelProvider, TravelProviderLoginConfiguration {
    public let id = ProviderID.check24
    public let displayName = "Check24"

    public var loginURL: URL { URL(string: "https://kundenbereich.check24.de/user/login.html")! }
    public var keychainServerHost: String { "check24.de" }

    public var onProgress: (@MainActor (String) -> Void)?

    public init() {}

    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        let webView = try webView(from: session)
        guard webView.url != nil else { throw Check24ProviderError.sessionNotEstablished }

        let activity = try await fetchActivity(using: webView)
        guard !activity.bookings.isEmpty else { return ProviderCatalog(bookings: []) }

        onProgress?("Prüfe Stornofristen…")

        var deadlinesByBookingURL: [String: [ParsedCancellationDeadline]] = [:]
        var hotelStayByBookingURL: [String: HotelCheckInOut] = [:]
        var bookingDetailsByBookingKey: [String: ParsedBookingDetails] = [:]

        // Multi-Room/Basket: Hotels werden zu einer Buchung pro `basketId` gemerged.
        var basketsByBasketId: [String: HotelBasketParser.ParsedHotelBasket] = [:]
        var bookingUuidToBasketId: [String: String] = [:]
        var canonicalBookingUuidByBasketId: [String: String] = [:]
        var deadlinesByBasketId: [String: [ParsedCancellationDeadline]] = [:]
        var hotelStayByBasketId: [String: HotelCheckInOut] = [:]
        var bookingDetailsByBasketId: [String: ParsedBookingDetails] = [:]

        var parsedBookingByBookingUuid: [String: ParsedBooking] = [:]

        try await maybeApplyInitialPolicySnapshot(from: webView, into: &deadlinesByBookingURL)

        let hotelBookingsWithURL = bookingsWithURL(for: .hotel, in: activity)
        try await enrichHotelBookings(
            hotelBookingsWithURL: hotelBookingsWithURL,
            webView: webView,
            deadlinesByBookingURL: &deadlinesByBookingURL,
            hotelStayByBookingURL: &hotelStayByBookingURL,
            bookingDetailsByBookingKey: &bookingDetailsByBookingKey,
            basketsByBasketId: &basketsByBasketId,
            bookingUuidToBasketId: &bookingUuidToBasketId,
            canonicalBookingUuidByBasketId: &canonicalBookingUuidByBasketId,
            deadlinesByBasketId: &deadlinesByBasketId,
            hotelStayByBasketId: &hotelStayByBasketId,
            bookingDetailsByBasketId: &bookingDetailsByBasketId,
            parsedBookingByBookingUuid: &parsedBookingByBookingUuid
        )

        let nonHotelBookingsWithURL = bookingsWithURL(for: .nonHotel, in: activity)
        try await enrichNonHotelBookings(
            nonHotelBookingsWithURL: nonHotelBookingsWithURL,
            webView: webView,
            bookingDetailsByBookingKey: &bookingDetailsByBookingKey
        )

        var draftByExternalUrl = makeBasketDrafts(
            basketsByBasketId: basketsByBasketId,
            canonicalBookingUuidByBasketId: canonicalBookingUuidByBasketId,
            parsedBookingByBookingUuid: parsedBookingByBookingUuid,
            deadlinesByBasketId: deadlinesByBasketId,
            deadlinesByBookingURL: deadlinesByBookingURL,
            hotelStayByBasketId: hotelStayByBasketId,
            hotelStayByBookingURL: hotelStayByBookingURL,
            bookingDetailsByBasketId: bookingDetailsByBasketId,
            bookingDetailsByBookingKey: bookingDetailsByBookingKey
        )

        addNonBasketDrafts(
            activity: activity,
            bookingUuidToBasketId: bookingUuidToBasketId,
            deadlinesByBookingURL: deadlinesByBookingURL,
            hotelStayByBookingURL: hotelStayByBookingURL,
            bookingDetailsByBookingKey: bookingDetailsByBookingKey,
            draftByExternalUrl: &draftByExternalUrl
        )

        let sorted = Array(draftByExternalUrl.values).sorted { $0.startAt < $1.startAt }
        return ProviderCatalog(bookings: sorted)
    }
}
