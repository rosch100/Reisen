import Foundation
import ReisenDomain

/// Parst GetYourGuide `myBookings` (Fixture oder `__INITIAL_STATE__.myBookings`) → Katalog-Drafts.
public enum GetYourGuideMyBookingsParser {
    public static func parse(from jsonText: String) throws -> ProviderCatalog {
        let data = Data(jsonText.utf8)
        let payload = try decodePayload(from: data)
        let drafts = (payload.upcomingBookings ?? []).compactMap { mapBooking($0) }
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

    private static func mapBooking(_ booking: GYGListBooking) -> ProviderBookingDraft? {
        let statusRaw = NonEmpty.string(booking.status)
        guard let startAt = booking.startingTime?.startTime,
              let endAt = booking.bookingFinishDate else {
            return nil
        }

        let confirmationCode = NonEmpty.first(booking.bookingReference, booking.bookingHash)
        let bookingHash = NonEmpty.string(booking.bookingHash)
        let externalUrl: String? = bookingHash.map(GetYourGuideWebConstants.bookingURL(hash:))

        let title = booking.bookedOption?.activityTitle
        let locationTo = booking.bookedOption?.activityLocation?.city?.name
        let deadlines = booking.bookingCancellationPolicy?.asDeadlines() ?? []
        let participantCount = (booking.activityParticipants ?? []).reduce(0) { $0 + max(0, $1.count ?? 0) }
        let rateDetails: BookingRateDetails? = {
            guard let price = booking.price else { return nil }
            return BookingRateDetails(
                totalPriceAmount: price.amount,
                totalPriceCurrency: price.currencyIsoCode,
                guestCount: participantCount > 0 ? participantCount : nil,
                passengerCount: participantCount > 0 ? participantCount : nil
            )
        }()

        let times = TemporalFact.pair(bookingType: .activity, start: startAt, end: endAt)
        return DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .getYourGuide,
                bookingType: .activity,
                start: times.start,
                end: times.end,
                title: title,
                confirmationCode: confirmationCode,
                externalUrl: externalUrl,
                locationTo: locationTo,
                statusRaw: statusRaw,
                deadlines: deadlines,
                rateDetails: rateDetails
            )
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

private struct GYGMoney: Decodable {
    let amount: Double?
    let currencyIsoCode: String?
}

private struct GYGBookedOption: Decodable {
    let activityTitle: String?
    let activityLocation: GYGActivityLocation?
}

private struct GYGActivityLocation: Decodable {
    let city: GYGNamedPlace?
}

private struct GYGNamedPlace: Decodable {
    let name: String?
}

struct GYGCancellationPolicy: Decodable {
    let type: String?
    let policyType: String?
    let message: String?
    let expirationDate: Date?
    let policyExpirationDate: Date?
    let feeValue: Double?
}

struct GYGParticipant: Decodable {
    let count: Int?
    let priceCategoryLabel: String?
    let description: String?
    let localizedCount: String?
}
