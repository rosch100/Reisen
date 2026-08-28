import Foundation
import ReisenDomain

/// Parst GetYourGuide `myBookings` (Fixture oder `__INITIAL_STATE__.myBookings`) → Katalog-Drafts.
public enum GetYourGuideMyBookingsParser {
    public static func parse(from jsonText: String) throws -> ProviderCatalog {
        let payload = try decodePayload(from: Data(jsonText.utf8))
        return ProviderCatalog(bookings: uniqueDrafts(from: listedBookings(from: payload)))
    }

    private static func decodePayload(from data: Data) throws -> MyBookingsPayload {
        if let envelope = GetYourGuideJSONDecoder.decode(MyBookingsEnvelope.self, from: data),
           let nested = envelope.myBookings
        {
            return nested
        }
        if let direct = GetYourGuideJSONDecoder.decode(MyBookingsPayload.self, from: data),
           direct.upcomingBookings != nil || direct.pastBookings != nil
        {
            return direct
        }
        throw GetYourGuideProviderError.myBookingsNotFound
    }

    private static func listedBookings(from payload: MyBookingsPayload) -> [GYGListBooking] {
        (payload.upcomingBookings ?? []) + (payload.pastBookings ?? [])
    }

    private static func uniqueDrafts(from bookings: [GYGListBooking]) -> [ProviderBookingDraft] {
        var seenHashes = Set<String>()
        var drafts: [ProviderBookingDraft] = []
        drafts.reserveCapacity(bookings.count)
        for booking in bookings {
            guard let mapped = mapBooking(booking), seenHashes.insert(mapped.hash).inserted else {
                continue
            }
            drafts.append(mapped.draft)
        }
        return drafts
    }

    private static func mapBooking(_ booking: GYGListBooking) -> MappedListBooking? {
        guard let status = GetYourGuideParsing.catalogStatus(booking.status) else { return nil }
        guard let hash = NonEmpty.string(booking.bookingHash) else { return nil }
        guard let startAt = booking.startingTime?.startTime else { return nil }
        guard let endAt = booking.bookingFinishDate else { return nil }
        let times = TemporalFact.pair(bookingType: .activity, start: startAt, end: endAt)
        guard let window = BookingDateWindow.resolve(type: .activity, start: times.start, end: times.end) else {
            return nil
        }

        let draft = ProviderBookingDraft(
            provider: .getYourGuide,
            bookingType: .activity,
            title: booking.bookedOption?.activityTitle,
            confirmationCode: NonEmpty.first(booking.bookingReference, hash),
            externalUrl: GetYourGuideWebConstants.bookingURL(hash: hash),
            startAt: window.startAt,
            endAt: window.endAt,
            locationTo: booking.bookedOption?.activityLocation?.city?.name,
            status: status,
            deadlines: booking.bookingCancellationPolicy?.asDeadlines() ?? [],
            rateDetails: rateDetails(from: booking)
        )
        return MappedListBooking(hash: hash, draft: draft)
    }

    private static func rateDetails(from booking: GYGListBooking) -> BookingRateDetails? {
        guard let price = booking.price else { return nil }
        let occupancy = GetYourGuideParsing.occupancy(of: booking.activityParticipants)
        return BookingRateDetails(
            totalPriceAmount: price.amount,
            totalPriceCurrency: price.currencyIsoCode,
            guestCount: occupancy,
            passengerCount: occupancy
        )
    }
}

private struct MappedListBooking {
    let hash: String
    let draft: ProviderBookingDraft
}

private struct MyBookingsEnvelope: Decodable {
    let myBookings: MyBookingsPayload?
}

private struct MyBookingsPayload: Decodable {
    let upcomingBookings: [GYGListBooking]?
    let pastBookings: [GYGListBooking]?
}

private struct GYGListBooking: Decodable {
    let bookingHash: String?
    let bookingReference: String?
    let status: String?
    let startingTime: GYGStartingTime?
    let bookingFinishDate: Date?
    let price: GYGMoney?
    let bookedOption: GYGBookedOption?
    let bookingCancellationPolicy: GYGCancellationPolicy?
    let activityParticipants: [GYGParticipant]?
}

private struct GYGStartingTime: Decodable {
    let startTime: Date?
}

private struct GYGBookedOption: Decodable {
    let activityTitle: String?
    let activityLocation: GYGActivityLocation?
}

private struct GYGActivityLocation: Decodable {
    let city: GYGNamedPlace?
}
