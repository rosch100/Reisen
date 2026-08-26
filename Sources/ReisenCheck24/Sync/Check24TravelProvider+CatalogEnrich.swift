import Foundation
import WebKit
import ReisenDomain

extension Check24TravelProvider {
    func enrichHotelBookings(
        hotelBookingsWithURL: [(ParsedBooking, URL)],
        webView: WKWebView,
        deadlinesByBookingURL: inout [String: [ParsedCancellationDeadline]],
        hotelStayByBookingURL: inout [String: HotelCheckInOut],
        guestHintsByBookingURL: inout [String: [BookingGuestHint]],
        bookingDetailsByBookingKey: inout [String: ParsedBookingDetails],
        basketsByBasketId: inout [String: HotelBasketParser.ParsedHotelBasket],
        bookingUuidToBasketId: inout [String: String],
        canonicalBookingUuidByBasketId: inout [String: String],
        deadlinesByBasketId: inout [String: [ParsedCancellationDeadline]],
        hotelStayByBasketId: inout [String: HotelCheckInOut],
        guestHintsByBasketId: inout [String: [BookingGuestHint]],
        bookingDetailsByBasketId: inout [String: ParsedBookingDetails],
        parsedBookingByBookingUuid: inout [String: ParsedBooking]
    ) async throws {
        for (index, item) in hotelBookingsWithURL.enumerated() {
            let (parsedBooking, bookingURL) = item
            let bookingURLString = parsedBooking.externalUrl ?? bookingURL.absoluteString

            if let externalUrl = parsedBooking.externalUrl {
                let bookingUuid = String(externalUrl.split(separator: "/").last ?? "")
                parsedBookingByBookingUuid[bookingUuid] = parsedBooking

                if let basketId = bookingUuidToBasketId[bookingUuid],
                   basketsByBasketId[basketId] != nil,
                   let hints = guestHintsByBasketId[basketId], !hints.isEmpty {
                    continue
                }
            }

            if let key = identityKey(for: parsedBooking),
               bookingDetailsByBookingKey[key] != nil {
                continue
            }

            onProgress?("Stornofrist \(index + 1)/\(hotelBookingsWithURL.count)…")
            try await enrichHotelDetail(
                webView: webView,
                parsedBooking: parsedBooking,
                bookingURL: bookingURL,
                bookingURLString: bookingURLString,
                deadlinesByBookingURL: &deadlinesByBookingURL,
                hotelStayByBookingURL: &hotelStayByBookingURL,
                guestHintsByBookingURL: &guestHintsByBookingURL,
                bookingDetailsByBookingKey: &bookingDetailsByBookingKey,

                basketsByBasketId: &basketsByBasketId,
                bookingUuidToBasketId: &bookingUuidToBasketId,
                canonicalBookingUuidByBasketId: &canonicalBookingUuidByBasketId,
                deadlinesByBasketId: &deadlinesByBasketId,
                hotelStayByBasketId: &hotelStayByBasketId,
                guestHintsByBasketId: &guestHintsByBasketId,
                bookingDetailsByBasketId: &bookingDetailsByBasketId
            )
        }
    }

    func enrichNonHotelBookings(
        nonHotelBookingsWithURL: [(ParsedBooking, URL)],
        webView: WKWebView,
        bookingDetailsByBookingKey: inout [String: ParsedBookingDetails]
    ) async throws {
        for (index, item) in nonHotelBookingsWithURL.enumerated() {
            let (parsedBooking, bookingURL) = item

            if let key = identityKey(for: parsedBooking),
               bookingDetailsByBookingKey[key] != nil {
                continue
            }

            onProgress?("Details \(index + 1)/\(nonHotelBookingsWithURL.count)…")
            try await enrichNonHotelDetail(
                webView: webView,
                parsedBooking: parsedBooking,
                bookingURL: bookingURL,
                bookingDetailsByBookingKey: &bookingDetailsByBookingKey
            )
        }
    }
}
