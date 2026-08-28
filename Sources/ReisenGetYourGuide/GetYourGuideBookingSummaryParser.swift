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
        let locationToAddress = NonEmpty.first(
            meeting?.location?.address,
            meeting?.description
        )

        let deadlines = summary.booking?.bookingCancellationPolicy?.asDeadlines() ?? []
        let participants = mapPassengers(summary.booking?.activityParticipants ?? [])
        let passengerCount = participants.count
        let guestHints = mapGuestHints(summary.activity)

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

        return DraftAssembler.enrichment(
            from: ProviderBookingFacts(
                provider: .getYourGuide,
                bookingType: .activity,
                title: summary.activity?.activityTitle,
                locationTo: summary.activity?.activityLocations?.city?.name,
                locationToAddress: locationToAddress,
                statusRaw: summary.booking?.status,
                deadlines: deadlines,
                rateDetails: rateDetails,
                passengers: participants,
                guestHints: guestHints
            )
        )
    }

    private static func mapGuestHints(_ activity: ActivityDTO?) -> [BookingGuestHint] {
        guard let activity else { return [] }
        let itineraryLines: [String] = (activity.itinerary?.items ?? []).compactMap { item in
            guard item.isImportant == true || item.type == "meeting_point" else { return nil }
            return NonEmpty.first(item.activityLabel, item.title, item.locationName)
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
            let count = max(0, participant.count ?? 0)
            let type = TravellerType.parse(participant.priceCategoryLabel)
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
