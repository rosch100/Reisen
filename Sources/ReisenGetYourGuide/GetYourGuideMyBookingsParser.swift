import Foundation
import ReisenDomain

/// Parst GetYourGuide `myBookings` (Fixture oder `__INITIAL_STATE__.myBookings`) → Katalog-Drafts.
public enum GetYourGuideMyBookingsParser {
    public static func parse(from jsonText: String) throws -> ProviderCatalog {
        let data = Data(jsonText.utf8)
        let payload = try decodePayload(from: data)
        // upcoming + past: GYG schiebt beendete Termine nach past (HAR 2026-08-28), ohne Pagination.
        let listed = listedBookings(from: payload)
        var seenHashes = Set<String>()
        var drafts: [ProviderBookingDraft] = []
        drafts.reserveCapacity(listed.count)
        for booking in listed {
            if let hash = NonEmpty.string(booking.bookingHash), !seenHashes.insert(hash).inserted {
                continue
            }
            if let draft = mapBooking(booking) {
                drafts.append(draft)
            }
        }
        return ProviderCatalog(bookings: drafts)
    }

    private static func decodePayload(from data: Data) throws -> MyBookingsPayload {
        if let envelope = try? GetYourGuideJSONDecoder.shared.decode(MyBookingsEnvelope.self, from: data),
           let nested = envelope.myBookings
        {
            return nested
        }
        if let direct = try? GetYourGuideJSONDecoder.shared.decode(MyBookingsPayload.self, from: data),
           direct.upcomingBookings != nil || direct.pastBookings != nil
        {
            return direct
        }
        throw GetYourGuideProviderError.myBookingsNotFound
    }

    private static func listedBookings(from payload: MyBookingsPayload) -> [GYGListBooking] {
        (payload.upcomingBookings ?? []) + (payload.pastBookings ?? [])
    }

    private static func mapBooking(_ booking: GYGListBooking) -> ProviderBookingDraft? {
        guard let status = GetYourGuideParsing.catalogStatus(booking.status) else { return nil }
        guard let startAt = booking.startingTime?.startTime else { return nil }
        guard let endAt = booking.bookingFinishDate else { return nil }

        let hash = NonEmpty.string(booking.bookingHash)
        let times = TemporalFact.pair(bookingType: .activity, start: startAt, end: endAt)
        guard let window = BookingDateWindow.resolve(type: .activity, start: times.start, end: times.end) else {
            return nil
        }

        return ProviderBookingDraft(
            provider: .getYourGuide,
            bookingType: .activity,
            title: booking.bookedOption?.activityTitle,
            confirmationCode: NonEmpty.first(booking.bookingReference, hash),
            externalUrl: hash.map(GetYourGuideWebConstants.bookingURL(hash:)),
            startAt: window.startAt,
            endAt: window.endAt,
            locationTo: booking.bookedOption?.activityLocation?.city?.name,
            status: status,
            deadlines: booking.bookingCancellationPolicy?.asDeadlines() ?? [],
            rateDetails: rateDetails(from: booking)
        )
    }

    private static func rateDetails(from booking: GYGListBooking) -> BookingRateDetails? {
        guard let price = booking.price else { return nil }
        let occupancy = GetYourGuideParsing.occupancy(
            (booking.activityParticipants ?? []).reduce(0) { $0 + GetYourGuideParsing.participantCount($1) }
        )
        return BookingRateDetails(
            totalPriceAmount: price.amount,
            totalPriceCurrency: price.currencyIsoCode,
            guestCount: occupancy,
            passengerCount: occupancy
        )
    }
}

// MARK: - DTOs

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
