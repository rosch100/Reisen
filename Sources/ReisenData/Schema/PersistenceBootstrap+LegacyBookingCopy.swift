import Foundation
import SwiftData

extension PersistenceBootstrap {
    static func copyBookings(
        from source: ModelContext,
        to target: ModelContext,
        tripByID: [UUID: SDTrip]
    ) throws -> [UUID: SDBooking] {
        let bookings = try source.fetch(FetchDescriptor<SDBooking>())
        var bookingByID: [UUID: SDBooking] = [:]
        for booking in bookings {
            let copy = makeLegacyBookingCopy(booking)
            if let tripID = booking.trip?.id {
                copy.trip = tripByID[tripID]
            }
            target.insert(copy)
            bookingByID[copy.id] = copy

            copyLegacyDeadlines(from: booking, onto: copy, in: target)
            copyLegacyPassengers(from: booking, onto: copy, in: target)
            copyLegacyRateDetails(from: booking, onto: copy, in: target)
        }
        return bookingByID
    }

    static func makeLegacyBookingCopy(_ booking: SDBooking) -> SDBooking {
        SDBooking(
            id: booking.id,
            providerRaw: booking.providerRaw,
            bookingTypeRaw: booking.bookingTypeRaw,
            title: booking.title,
            confirmationCode: booking.confirmationCode,
            externalUrl: booking.externalUrl,
            cancellationUrl: booking.cancellationUrl,
            startAt: booking.startAt,
            endAt: booking.endAt,
            locationFrom: booking.locationFrom,
            locationTo: booking.locationTo,
            locationFromAddress: booking.locationFromAddress,
            locationToAddress: booking.locationToAddress,
            operatorName: booking.operatorName,
            isAllDay: booking.isAllDay,
            statusRaw: booking.statusRaw,
            lastSyncedAt: booking.lastSyncedAt,
            rawPayloadFingerprint: booking.rawPayloadFingerprint,
            hotelOffsetSeconds: booking.hotelOffsetSeconds,
            flightDepartureOffsetSeconds: booking.flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: booking.flightArrivalOffsetSeconds,
            hotelCheckInMinutes: booking.hotelCheckInMinutes,
            hotelCheckOutMinutes: booking.hotelCheckOutMinutes,
            timesSourceFingerprint: booking.timesSourceFingerprint,
            timesNormalized: booking.timesNormalized
        )
    }

    static func copyLegacyDeadlines(
        from booking: SDBooking,
        onto copy: SDBooking,
        in target: ModelContext
    ) {
        for deadline in booking.resolvedCancellationDeadlines {
            let d = SDCancellationDeadline(
                id: deadline.id,
                deadlineAt: deadline.deadlineAt,
                policyText: deadline.policyText,
                isStrict: deadline.isStrict,
                isFreeCancellation: deadline.isFreeCancellation,
                hotelOffsetSeconds: deadline.hotelOffsetSeconds,
                cancellationFeeAmount: deadline.cancellationFeeAmount,
                booking: copy
            )
            target.insert(d)
        }
    }

    static func copyLegacyPassengers(
        from booking: SDBooking,
        onto copy: SDBooking,
        in target: ModelContext
    ) {
        for passenger in booking.resolvedPassengers {
            let p = SDBookingPassenger(
                id: passenger.id,
                booking: copy,
                passengerID: passenger.passengerID,
                passengerNumber: passenger.passengerNumber,
                travellerTypeRaw: passenger.travellerTypeRaw,
                title: passenger.title,
                givenName: passenger.givenName,
                familyName: passenger.familyName,
                secondFamilyName: passenger.secondFamilyName,
                birthDate: passenger.birthDate
            )
            target.insert(p)
            for allowance in passenger.resolvedBaggageAllowances {
                let a = SDBaggageAllowance(
                    id: allowance.id,
                    passenger: p,
                    baggageTypeRaw: allowance.baggageTypeRaw,
                    pieceCount: allowance.pieceCount,
                    weightKg: allowance.weightKg,
                    sectionID: allowance.sectionID,
                    airlineCode: allowance.airlineCode,
                    fromLabel: allowance.fromLabel,
                    toLabel: allowance.toLabel
                )
                target.insert(a)
            }
        }
    }

    static func copyLegacyRateDetails(
        from booking: SDBooking,
        onto copy: SDBooking,
        in target: ModelContext
    ) {
        guard let details = booking.rateDetails else { return }
        let rate = SDBookingRateDetails(
            id: details.id,
            booking: copy,
            rawDetailsFingerprint: details.rawDetailsFingerprint,
            totalPriceAmount: details.totalPriceAmount,
            totalPriceCurrency: details.totalPriceCurrency,
            roomCategory: details.roomCategory,
            boardTypeRaw: details.boardTypeRaw,
            includedBreakfast: details.includedBreakfast,
            guestCount: details.guestCount,
            roomCount: details.roomCount,
            airline: details.airline,
            passengerCount: details.passengerCount,
            baggageInfoRaw: details.baggageInfoRaw,
            lastParsedAt: details.lastParsedAt
        )
        target.insert(rate)
        for room in details.resolvedRoomItems {
            let item = SDBookingRoomItem(
                id: room.id,
                rateDetails: rate,
                category: room.category,
                confirmationCode: room.confirmationCode,
                priceAmount: room.priceAmount,
                priceCurrency: room.priceCurrency,
                guestSummary: room.guestSummary,
                externalUrl: room.externalUrl,
                sortIndex: room.sortIndex
            )
            target.insert(item)
        }
    }
}
