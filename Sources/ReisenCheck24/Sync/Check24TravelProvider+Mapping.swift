import Foundation
import ReisenDomain
import ReisenProviders

extension Check24TravelProvider {
    func mapDraft(
        _ parsed: ParsedBooking,
        allBookings: [ParsedBooking],
        deadlinesByBookingURL: [String: [ParsedCancellationDeadline]],
        hotelStayByBookingURL: [String: HotelCheckInOut],
        guestHintsByBookingURL: [String: [BookingGuestHint]],
        bookingDetailsByBookingKey: [String: ParsedBookingDetails],
        carRentalDetail: ParsedCarRentalDetail? = nil
    ) -> ProviderBookingDraft? {
        let url = parsed.externalUrl
        let deadlines = (url.flatMap { deadlinesByBookingURL[$0] } ?? []).map(\.asDomain)
        let stay = url.flatMap { hotelStayByBookingURL[$0] }
        let guestHints = url.flatMap { guestHintsByBookingURL[$0] } ?? []
        let enrichedDetails = parsed.identityKey.flatMap { bookingDetailsByBookingKey[$0] }
        let details = ParsedBookingDetails.merging(enrichedDetails, with: parsed.details)
        let catalogRates = HotelBookingPriceResolver.resolve(
            booking: parsed,
            siblings: allBookings,
            detail: details
        )
        let times = TemporalFact.pair(
            bookingType: parsed.type,
            start: parsed.startAt,
            end: parsed.endAt
        )

        var facts = ProviderBookingFacts(
            provider: .check24,
            bookingType: parsed.type,
            start: times.start,
            end: times.end,
            title: parsed.title,
            confirmationCode: parsed.confirmationCode,
            externalUrl: parsed.externalUrl,
            locationFrom: parsed.locationFrom,
            locationTo: NonEmpty.first(parsed.locationTo, stay?.locationTo),
            locationFromAddress: parsed.locationFromAddress,
            locationToAddress: NonEmpty.first(parsed.locationToAddress, stay?.locationToAddress),
            statusRaw: parsed.statusRaw,
            deadlines: deadlines,
            rateDetails: catalogRates,
            hotelCheckInMinutes: stay?.checkInMinutes,
            hotelCheckOutMinutes: stay?.checkOutMinutes,
            rawPayloadFingerprint: details?.rawDetailsFingerprint,
            guestHints: guestHints
        )
        carRentalDetail?.apply(to: &facts)
        return DraftAssembler.draft(from: facts)
    }
}
