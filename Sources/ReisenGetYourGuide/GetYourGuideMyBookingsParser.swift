import Foundation
import ReisenDomain

/// Parst GetYourGuide `myBookings` (Fixture oder `__INITIAL_STATE__.myBookings`) → Katalog-Drafts.
public enum GetYourGuideMyBookingsParser {
    public static func parse(from jsonText: String) throws -> ProviderCatalog {
        let payload = try decodePayload(from: Data(jsonText.utf8))
        let drafts = listedBookings(from: payload).compactMap(mapBooking)
        return ProviderCatalog(bookings: drafts).dedupedByExternalURL()
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

    private static func mapBooking(_ booking: GYGListBooking) -> ProviderBookingDraft? {
        guard let hash = NonEmpty.string(booking.bookingHash),
              let startAt = booking.startingTime?.startTime,
              let endAt = booking.bookingFinishDate
        else {
            return nil
        }
        let times = TemporalFact.pair(bookingType: .activity, start: startAt, end: endAt)
        return DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .getYourGuide,
                bookingType: .activity,
                start: times.start,
                end: times.end,
                title: booking.bookedOption?.activityTitle,
                confirmationCode: NonEmpty.first(booking.bookingReference, hash),
                externalUrl: GetYourGuideWebConstants.bookingURL(hash: hash),
                locationTo: booking.bookedOption?.activityLocation?.city?.name,
                statusRaw: booking.status,
                deadlines: GYGCancellationPolicy.deadlines(booking.bookingCancellationPolicy),
                rateDetails: GetYourGuideParsing.rateDetails(
                    price: booking.price,
                    occupancy: GetYourGuideParsing.occupancy(of: booking.activityParticipants)
                )
            )
        )
    }
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
