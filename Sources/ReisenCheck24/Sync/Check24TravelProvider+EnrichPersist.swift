import Foundation

extension Check24TravelProvider {
    func persistBasketState(
        basketId: String,
        parsedBasket: HotelBasketParser.ParsedHotelBasket?,
        bookingURLString: String,
        basketsByBasketId: inout [String: HotelBasketParser.ParsedHotelBasket],
        bookingUuidToBasketId: inout [String: String],
        canonicalBookingUuidByBasketId: inout [String: String]
    ) {
        if basketsByBasketId[basketId] == nil, let parsedBasket {
            basketsByBasketId[basketId] = parsedBasket
        }
        if let basket = basketsByBasketId[basketId] {
            for item in basket.items {
                bookingUuidToBasketId[item.bookingUuid] = basketId
            }
        }

        // Robust: kanonische Activity-UUID anhand der gerade geladenen Detail-URL.
        // So bleibt der Merge korrekt, auch wenn `basket.items[].bookingUuid`
        // nicht 1:1 mit Activity-`foreignId`/Zimmer-UUIDs übereinstimmt.
        let currentBookingUuid = bookingURLString.split(separator: "/").last.flatMap(String.init)
        if let currentBookingUuid, canonicalBookingUuidByBasketId[basketId] == nil {
            canonicalBookingUuidByBasketId[basketId] = currentBookingUuid
        }
    }

    func persistBasketDetails(
        basketId: String,
        parsedDetails: ParsedBookingDetails,
        policyDeadlines: [ParsedCancellationDeadline],
        stay: HotelCheckInOut,
        bookingURLString: String,
        bookingDetailsByBasketId: inout [String: ParsedBookingDetails],
        deadlinesByBasketId: inout [String: [ParsedCancellationDeadline]],
        deadlinesByBookingURL: inout [String: [ParsedCancellationDeadline]],
        hotelStayByBasketId: inout [String: HotelCheckInOut],
        hotelStayByBookingURL: inout [String: HotelCheckInOut]
    ) {
        if bookingDetailsByBasketId[basketId] == nil {
            bookingDetailsByBasketId[basketId] = parsedDetails
        }

        if !policyDeadlines.isEmpty {
            deadlinesByBasketId[basketId] = policyDeadlines
            deadlinesByBookingURL[bookingURLString] = policyDeadlines
        }

        if stay.checkInMinutes != nil || stay.checkOutMinutes != nil {
            hotelStayByBasketId[basketId] = stay
            hotelStayByBookingURL[bookingURLString] = stay
        }
    }

    func persistNonBasketDetails(
        parsedBooking: ParsedBooking,
        parsedDetails: ParsedBookingDetails,
        stay: HotelCheckInOut,
        policyDeadlines: [ParsedCancellationDeadline],
        bookingURLString: String,
        bookingDetailsByBookingKey: inout [String: ParsedBookingDetails],
        hotelStayByBookingURL: inout [String: HotelCheckInOut],
        deadlinesByBookingURL: inout [String: [ParsedCancellationDeadline]]
    ) {
        if let key = identityKey(for: parsedBooking) {
            bookingDetailsByBookingKey[key] = parsedDetails
        }

        if stay.checkInMinutes != nil || stay.checkOutMinutes != nil {
            hotelStayByBookingURL[bookingURLString] = stay
        }

        if !policyDeadlines.isEmpty {
            deadlinesByBookingURL[bookingURLString] = policyDeadlines
        }
    }
}
