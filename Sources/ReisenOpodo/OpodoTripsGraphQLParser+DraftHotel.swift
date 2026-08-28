import Foundation
import ReisenDomain

extension OpodoTripsGraphQLParser {
    func draftHotel(
        trip: OpodoGraphQLTrip,
        hotel: OpodoGraphQLAccommodation,
        externalUrl: String,
        rateDetails: BookingRateDetails?
    ) -> ProviderBookingDraft? {
        guard let rawStart = dateFromEpochMillis(hotel.checkInDate),
              let rawEnd = dateFromEpochMillis(hotel.checkOutDate) else {
            return nil
        }

        let details = BookingRateDetails.merging(
            existing: rateDetails,
            incoming: incomingHotelRates(hotel: hotel)
        )

        let times = TemporalFact.pair(bookingType: .hotel, start: rawStart, end: rawEnd)
        return DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .opodo,
                bookingType: .hotel,
                start: times.start,
                end: times.end,
                title: hotel.accommodationName,
                confirmationCode: hotel.id ?? trip.id,
                externalUrl: externalUrl,
                locationTo: hotel.city,
                locationToAddress: PostalAddress.lines(
                    street: hotel.address,
                    postalCode: hotel.postalCode,
                    city: hotel.city,
                    country: hotel.countryCode
                ),
                statusRaw: BookingStatus.joinedRaw(
                    hotel.bookingStatus ?? trip.bookingStatus,
                    trip.bookingProductStatus
                ),
                rateDetails: details,
                hotelCheckInMinutes: parseClockMinutes(hotel.checkIn),
                hotelCheckOutMinutes: parseClockMinutes(hotel.checkOut)
            )
        )
    }

    private func incomingHotelRates(hotel: OpodoGraphQLAccommodation) -> BookingRateDetails? {
        let adults = hotel.numberOfAdults ?? 0
        let children = hotel.numberOfChildren ?? 0
        let guestCount = (adults + children) > 0 ? (adults + children) : nil
        let board = BookingBoardType.parse(hotel.boardType)
        let roomCategory = roomCategory(from: hotel.bookingRooms)
        let roomItems = roomItems(from: hotel.bookingRooms)
        guard hotel.boardType != nil
                || hotel.numberOfRooms != nil
                || roomCategory != nil
                || !roomItems.isEmpty
                || guestCount != nil else {
            return nil
        }
        return BookingRateDetails(
            roomCategory: roomCategory,
            boardType: board,
            includedBreakfast: board.includedBreakfast,
            guestCount: guestCount,
            roomCount: hotel.numberOfRooms,
            roomItems: roomItems
        )
    }
}
