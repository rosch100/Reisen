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

        // Hotels: nur Kalenderdatum — Uhrzeit/TZ verwerfen.
        let startAt = HotelStayDate.dateOnly(fromStoredOrParsed: rawStart)
        let endAt = HotelStayDate.dateOnly(fromStoredOrParsed: rawEnd)
        let adults = hotel.numberOfAdults ?? 0
        let children = hotel.numberOfChildren ?? 0
        let guestCount = (adults + children) > 0 ? (adults + children) : nil
        let board = boardType(from: hotel.boardType)
        let roomCategory = roomCategory(from: hotel.bookingRooms)
        let roomItems = roomItems(from: hotel.bookingRooms)

        var details = rateDetails
        if var existing = details {
            existing.boardType = board
            existing.roomCount = hotel.numberOfRooms
            existing.guestCount = guestCount
            existing.includedBreakfast = board == .breakfastIncluded
            existing.roomCategory = roomCategory
            if !roomItems.isEmpty {
                existing.roomItems = roomItems
            }
            details = existing
        } else if hotel.boardType != nil || hotel.numberOfRooms != nil || roomCategory != nil {
            details = BookingRateDetails(
                roomCategory: roomCategory,
                boardType: board,
                includedBreakfast: board == .breakfastIncluded,
                guestCount: guestCount,
                roomCount: hotel.numberOfRooms,
                roomItems: roomItems
            )
        }

        return ProviderBookingDraft(
            provider: .opodo,
            bookingType: .hotel,
            title: hotel.accommodationName,
            confirmationCode: hotel.id ?? trip.id,
            externalUrl: externalUrl,
            startAt: startAt,
            endAt: endAt,
            locationFrom: nil,
            locationTo: hotel.city,
            locationToAddress: hotelAddress(
                street: hotel.address,
                postalCode: hotel.postalCode,
                city: hotel.city,
                countryCode: hotel.countryCode
            ),
            status: status(bookingStatus: hotel.bookingStatus ?? trip.bookingStatus, productStatus: trip.bookingProductStatus),
            rateDetails: details,
            hotelCheckInMinutes: parseClockMinutes(hotel.checkIn),
            hotelCheckOutMinutes: parseClockMinutes(hotel.checkOut)
        )
    }
}
