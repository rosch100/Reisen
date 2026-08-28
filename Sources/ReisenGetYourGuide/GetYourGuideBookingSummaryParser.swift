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
        if let bookingEnvelope = GetYourGuideJSONDecoder.decode(BookingEnvelope.self, from: data),
           let summary = bookingEnvelope.booking?.bookingSummary ?? bookingEnvelope.bookingSummary
        {
            return summary
        }
        if let wrapper = GetYourGuideJSONDecoder.decode(SummaryWrapper.self, from: data),
           let summary = wrapper.bookingSummary
        {
            return summary
        }
        if let direct = GetYourGuideJSONDecoder.decode(BookingSummaryDTO.self, from: data),
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

        let deadlines = GYGCancellationPolicy.deadlines(summary.booking?.bookingCancellationPolicy)
        let guests = GetYourGuideParsing.guests(from: summary.booking?.activityParticipants)
        let guestHints = mapGuestHints(summary.activity)
        let rateDetails = GetYourGuideParsing.rateDetails(
            price: summary.booking?.price,
            occupancy: guests.occupancy,
            roomCategory: summary.activity?.activityOptionTitle
        )

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
                passengers: guests.passengers,
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
