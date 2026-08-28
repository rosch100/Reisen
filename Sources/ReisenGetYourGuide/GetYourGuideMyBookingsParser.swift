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
            guard let mapped = mapBooking(booking), seenHashes.insert(mapped.hash).inserted else { continue }
            drafts.append(mapped.draft)
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

    private static func mapBooking(_ booking: GYGListBooking) -> MappedListBooking? {
        guard let status = GetYourGuideParsing.catalogStatus(booking.status) else { return nil }
        guard let hash = GetYourGuideParsing.trimmedNonEmpty(booking.bookingHash) else { return nil }
        guard let startAt = booking.startingTime?.startTime else { return nil }
        guard let endAt = booking.bookingFinishDate else { return nil }

        let draft = ProviderBookingDraft(
            provider: .getYourGuide,
            bookingType: .activity,
            title: booking.bookedOption?.activityTitle,
            confirmationCode: GetYourGuideParsing.firstNonEmpty(booking.bookingReference, hash),
            externalUrl: GetYourGuideWebConstants.bookingURL(hash: hash),
            startAt: startAt,
            endAt: endAt,
            locationTo: booking.bookedOption?.activityLocation?.city?.name,
            status: status,
            deadlines: GetYourGuideParsing.deadlines(from: booking.bookingCancellationPolicy),
            rateDetails: rateDetails(from: booking)
        )
        return MappedListBooking(hash: hash, draft: draft)
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
