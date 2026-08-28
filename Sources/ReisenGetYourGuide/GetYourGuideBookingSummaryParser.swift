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
        let locationToAddress = GetYourGuideParsing.firstNonEmpty(
            meeting?.location?.address,
            meeting?.description
        )

        let deadlines = GetYourGuideParsing.deadlines(from: summary.booking?.bookingCancellationPolicy)
        let participants = mapPassengers(summary.booking?.activityParticipants ?? [])
        let occupancy = GetYourGuideParsing.occupancy(participants.count)
        let guestHints = mapGuestHints(summary.activity)
        let status = GetYourGuideParsing.detailStatus(summary.booking?.status)

        let rateDetails: BookingRateDetails? = {
            let price = summary.booking?.price
            guard price != nil || occupancy != nil else { return nil }
            return BookingRateDetails(
                totalPriceAmount: price?.amount,
                totalPriceCurrency: price?.currencyIsoCode,
                roomCategory: summary.activity?.activityOptionTitle,
                guestCount: occupancy,
                passengerCount: occupancy
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
            return GetYourGuideParsing.firstNonEmpty(item.activityLabel, item.title, item.locationName)
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

    /// Teilnehmer ohne PII (keine Namen aus `traveler`).
    private static func mapPassengers(_ participants: [GYGParticipant]) -> [BookingPassenger] {
        var result: [BookingPassenger] = []
        var number = 1
        for participant in participants {
            let count = GetYourGuideParsing.participantCount(participant)
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
    let city: GYGNamedPlace?
}

private struct SummaryBookingDTO: Decodable {
    let status: String?
    let price: GYGMoney?
    let bookingCancellationPolicy: GYGCancellationPolicy?
    let activityParticipants: [GYGParticipant]?
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
