import Foundation
import ReisenDomain
import ReisenProviders

extension Check24TravelProvider {
    func mapDraft(
        _ parsed: ParsedBooking,
        allBookings: [ParsedBooking],
        deadlinesByBookingURL: [String: [ParsedCancellationDeadline]],
        hotelStayByBookingURL: [String: HotelCheckInOut],
        bookingDetailsByBookingKey: [String: ParsedBookingDetails]
    ) -> ProviderBookingDraft {
        let url = parsed.externalUrl
        let deadlines = (url.flatMap { deadlinesByBookingURL[$0] } ?? []).map(mapDeadline)
        let stay = url.flatMap { hotelStayByBookingURL[$0] }
        let enrichedDetails = identityKey(for: parsed).flatMap { bookingDetailsByBookingKey[$0] }
        let details = mergeBookingDetails(primary: enrichedDetails, secondary: parsed.details)
        let rateDetails = HotelBookingPriceResolver.resolve(
            booking: parsed,
            siblings: allBookings,
            detail: details
        )

        return ProviderBookingDraft(
            provider: .check24,
            bookingType: parsed.type,
            title: parsed.title,
            confirmationCode: parsed.confirmationCode,
            externalUrl: parsed.externalUrl,
            startAt: parsed.startAt,
            endAt: parsed.endAt,
            locationFrom: parsed.locationFrom,
            locationTo: parsed.locationTo,
            locationFromAddress: parsed.locationFromAddress,
            locationToAddress: parsed.locationToAddress,
            status: parsed.status,
            deadlines: deadlines,
            rateDetails: rateDetails,
            hotelOffsetSeconds: deadlines.compactMap(\.hotelOffsetSeconds).first,
            hotelCheckInMinutes: stay?.checkInMinutes,
            hotelCheckOutMinutes: stay?.checkOutMinutes,
            rawPayloadFingerprint: details?.rawDetailsFingerprint
        )
    }

    func identityKey(for parsed: ParsedBooking) -> String? {
        if let url = parsed.externalUrl, !url.isEmpty { return "url:\(url)" }
        if let conf = parsed.confirmationCode, !conf.isEmpty {
            return "conf:\(conf)|start:\(parsed.startAt.timeIntervalSince1970)"
        }
        return nil
    }
}
