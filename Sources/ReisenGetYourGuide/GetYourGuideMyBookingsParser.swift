import Foundation
import ReisenDomain

/// Parst GetYourGuide `myBookings` (Fixture oder `__INITIAL_STATE__.myBookings`) → Katalog-Drafts.
public enum GetYourGuideMyBookingsParser {
    public static func parse(from jsonText: String) throws -> ProviderCatalog {
        let data = Data(jsonText.utf8)
        let payload = try decodePayload(from: data)
        let drafts = (payload.upcomingBookings ?? []).compactMap(mapBooking)
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
        guard let status = mapStatus(booking.status) else { return nil }
        guard let startAt = booking.startingTime?.startTime else { return nil }
        guard let endAt = booking.bookingFinishDate ?? booking.startingTime?.startTime else { return nil }

        let confirmationCode = firstNonEmpty(booking.bookingReference, booking.bookingHash)
        let bookingHash = booking.bookingHash?.trimmingCharacters(in: .whitespacesAndNewlines)
        let externalUrl: String? = {
            guard let hash = bookingHash, !hash.isEmpty else { return nil }
            return "https://www.getyourguide.com/de-de/booking/\(hash)"
        }()

        let title = booking.bookedOption?.activityTitle
        let locationTo = booking.bookedOption?.activityLocation?.city?.name
        let deadlines = mapDeadlines(booking.bookingCancellationPolicy)
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

        return ProviderBookingDraft(
            provider: .getYourGuide,
            bookingType: .activity,
            title: title,
            confirmationCode: confirmationCode,
            externalUrl: externalUrl,
            startAt: startAt,
            endAt: endAt,
            locationTo: locationTo,
            status: status,
            deadlines: deadlines,
            rateDetails: rateDetails
        )
    }

    /// `active` → confirmed, `cancelled` → cancelled, `done` → skip (past).
    private static func mapStatus(_ raw: String?) -> BookingStatus? {
        guard let raw else { return .unknown }
        switch raw.lowercased() {
        case "active":
            return .confirmed
        case "cancelled", "canceled":
            return .cancelled
        case "done":
            return nil
        default:
            return .unknown
        }
    }

    private static func mapDeadlines(_ policy: GYGCancellationPolicy?) -> [CancellationDeadline] {
        guard let policy else { return [] }
        guard let deadlineAt = policy.expirationDate ?? policy.policyExpirationDate else { return [] }
        let typeHaystack = [policy.type, policy.policyType]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        let isFree = typeHaystack.contains("freecancellation")
            || (policy.feeValue.map { $0 == 0 } ?? false)
        return [
            CancellationDeadline(
                deadlineAt: deadlineAt,
                policyText: policy.message,
                isFreeCancellation: isFree
            ),
        ]
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                continue
            }
            return trimmed
        }
        return nil
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
