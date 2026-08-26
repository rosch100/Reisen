import Foundation
import ReisenDomain

/// Parst GetYourGuide `booking.bookingSummary` → Enrichment (Treffpunkt, Fristen, Teilnehmer).
public enum GetYourGuideBookingSummaryParser {
    public static func parse(from jsonText: String) throws -> ProviderBookingEnrichment {
        let data = Data(jsonText.utf8)
        let summary = try decodeSummary(from: data)
        return map(summary)
    }

    private static func decodeSummary(from data: Data) throws -> BookingSummaryDTO {
        if let bookingEnvelope = try? GetYourGuideJSONDecoder.shared.decode(BookingEnvelope.self, from: data),
           let summary = bookingEnvelope.booking?.bookingSummary ?? bookingEnvelope.bookingSummary
        {
            return summary
        }
        if let wrapper = try? GetYourGuideJSONDecoder.shared.decode(SummaryWrapper.self, from: data),
           let summary = wrapper.bookingSummary
        {
            return summary
        }
        if let direct = try? GetYourGuideJSONDecoder.shared.decode(BookingSummaryDTO.self, from: data),
           direct.activity != nil || direct.booking != nil
        {
            return direct
        }
        throw GetYourGuideProviderError.bookingSummaryNotFound
    }

    private static func map(_ summary: BookingSummaryDTO) -> ProviderBookingEnrichment {
        let meeting = summary.activity?.meetingPoint
        let locationToAddress = firstNonEmpty(
            meeting?.location?.address,
            meeting?.description
        )

        let deadlines = mapDeadlines(summary.booking?.bookingCancellationPolicy)
        let participants = mapPassengers(summary.booking?.activityParticipants ?? [])
        let passengerCount = participants.count
        let guestHints = mapGuestHints(summary.activity)

        let status: BookingStatus? = {
            guard let raw = summary.booking?.status?.lowercased() else { return nil }
            switch raw {
            case "active": return .confirmed
            case "cancelled", "canceled": return .cancelled
            default: return nil
            }
        }()

        let rateDetails: BookingRateDetails? = {
            let price = summary.booking?.price
            guard price != nil || passengerCount > 0 else { return nil }
            return BookingRateDetails(
                totalPriceAmount: price?.amount,
                totalPriceCurrency: price?.currencyIsoCode,
                roomCategory: summary.activity?.activityOptionTitle,
                guestCount: passengerCount > 0 ? passengerCount : nil,
                passengerCount: passengerCount > 0 ? passengerCount : nil
            )
        }()

        return ProviderBookingEnrichment(
            deadlines: deadlines,
            rateDetails: rateDetails,
            passengers: participants.isEmpty ? nil : participants,
            guestHints: guestHints.isEmpty ? nil : guestHints,
            status: status,
            title: summary.activity?.activityTitle,
            locationTo: summary.activity?.activityLocations?.city?.name,
            locationToAddress: locationToAddress
        )
    }

    private static func mapGuestHints(_ activity: ActivityDTO?) -> [BookingGuestHint] {
        guard let activity else { return [] }
        let itineraryLines: [String] = (activity.itinerary?.items ?? []).compactMap { item in
            guard item.isImportant == true || item.type == "meeting_point" else { return nil }
            return firstNonEmpty(item.activityLabel, item.title, item.locationName)
        }
        return GetYourGuideGuestHintMapper.hints(
            from: GetYourGuideGuestHintActivity(
                meetingPointDescription: activity.meetingPoint?.description,
                meetingPointMinutesBefore: activity.meetingPoint?.minutesBefore,
                restrictions: activity.restrictions ?? [],
                inclusions: activity.inclusions ?? [],
                isMobileVoucherAccepted: activity.isMobileVoucherAccepted,
                importantItineraryLines: itineraryLines
            )
        )
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

    /// Teilnehmer ohne PII (keine Namen aus `traveler`).
    private static func mapPassengers(_ participants: [GYGParticipant]) -> [BookingPassenger] {
        var result: [BookingPassenger] = []
        var number = 1
        for participant in participants {
            let count = max(0, participant.count ?? 0)
            let type = travellerType(from: participant.priceCategoryLabel)
            for _ in 0..<count {
                result.append(
                    BookingPassenger(
                        passengerNumber: number,
                        travellerType: type,
                        title: participant.description
                    )
                )
                number += 1
            }
        }
        return result
    }

    private static func travellerType(from label: String?) -> TravellerType {
        switch label?.lowercased() {
        case "adult": return .adult
        case "child", "youth": return .child
        case "infant", "baby": return .infant
        default: return .unknown
        }
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

private struct BookingEnvelope: Decodable {
    let booking: BookingNode?
    let bookingSummary: BookingSummaryDTO?

    struct BookingNode: Decodable {
        let bookingSummary: BookingSummaryDTO?
    }
}

private struct SummaryWrapper: Decodable {
    let bookingSummary: BookingSummaryDTO?
}

private struct BookingSummaryDTO: Decodable {
    let activity: ActivityDTO?
    let booking: SummaryBookingDTO?
}

private struct ActivityDTO: Decodable {
    let activityTitle: String?
    let activityOptionTitle: String?
    let meetingPoint: MeetingPointDTO?
    let itinerary: GYGItinerary?
    let activityLocations: ActivityLocationsDTO?
    let inclusions: [String]?
    let restrictions: [String]?
    let isMobileVoucherAccepted: Bool?
}

private struct MeetingPointDTO: Decodable {
    let description: String?
    let minutesBefore: Int?
    let location: MeetingLocationDTO?
}

private struct MeetingLocationDTO: Decodable {
    let address: String?
}

private struct ActivityLocationsDTO: Decodable {
    let city: GYGNamedCity?
}

private struct GYGNamedCity: Decodable {
    let name: String?
}

private struct SummaryBookingDTO: Decodable {
    let status: String?
    let price: GYGMoneyDTO?
    let bookingCancellationPolicy: GYGCancellationPolicy?
    let activityParticipants: [GYGParticipant]?
}

private struct GYGMoneyDTO: Decodable {
    let amount: Double?
    let currencyIsoCode: String?
}

private struct GYGItinerary: Decodable {
    let items: [GYGItineraryItem]?
}

private struct GYGItineraryItem: Decodable {
    let title: String?
    let locationName: String?
    let type: String?
    let isImportant: Bool?
    let activityLabel: String?
}
