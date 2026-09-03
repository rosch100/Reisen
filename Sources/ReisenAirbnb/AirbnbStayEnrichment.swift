import Foundation
import ReisenDomain

/// Stay-Enrich: TripDetails-Adresse/Gäste/Zimmer + ScheduledEvents Preis/Zeiten/Hints.
enum AirbnbStayEnrichment {
    static func facts(
        bookingType: BookingType,
        tripDetails: AirbnbTripDetails,
        scheduled: AirbnbScheduledEventsParseResult,
        hotelOffsetSeconds: Int?,
        guestHints: [BookingGuestHint]
    ) -> ProviderBookingFacts {
        let stayCounts = BookingRateDetails(
            guestCount: tripDetails.guestAdults.flatMap { $0 > 0 ? $0 : nil },
            roomCount: tripDetails.roomCount.flatMap { $0 > 0 ? $0 : nil }
        )
        let rateDetails = BookingRateDetails.merging(
            existing: scheduled.rateDetails,
            incoming: stayCounts
        )
        return ProviderBookingFacts(
            provider: .airbnb,
            bookingType: bookingType,
            locationToAddress: tripDetails.oneLineAddress,
            statusRaw: tripDetails.reservationStatus,
            deadlines: scheduled.deadlines,
            rateDetails: rateDetails,
            hotelOffsetSeconds: hotelOffsetSeconds,
            hotelCheckInMinutes: scheduled.hotelCheckInMinutes,
            hotelCheckOutMinutes: scheduled.hotelCheckOutMinutes,
            guestHints: guestHints
        )
    }
}
