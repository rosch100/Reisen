import Foundation
import ReisenDomain

public enum DomainMapper {
    public static func trip(from model: SDTrip) -> Trip {
        Trip(
            id: model.id,
            title: model.title,
            startDate: model.startDate,
            endDate: model.endDate,
            destination: model.destination,
            notes: model.notes,
            bookingIDs: model.bookings.map(\.id)
        )
    }

    public static func booking(from model: SDBooking) -> Booking {
        Booking(
            id: model.id,
            provider: ProviderID(rawValue: model.providerRaw),
            bookingType: BookingType(rawValue: model.bookingTypeRaw) ?? .other,
            title: model.title,
            confirmationCode: model.confirmationCode,
            externalUrl: model.externalUrl,
            startAt: model.startAt,
            endAt: model.endAt,
            hotelOffsetSeconds: model.hotelOffsetSeconds,
            flightDepartureOffsetSeconds: model.flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: model.flightArrivalOffsetSeconds,
            hotelCheckInMinutes: model.hotelCheckInMinutes,
            hotelCheckOutMinutes: model.hotelCheckOutMinutes,
            timesSourceFingerprint: model.timesSourceFingerprint,
            timesNormalized: model.timesNormalized,
            locationFrom: model.locationFrom,
            locationTo: model.locationTo,
            locationFromAddress: model.locationFromAddress,
            locationToAddress: model.locationToAddress,
            status: BookingStatus(rawValue: model.statusRaw) ?? .unknown,
            lastSyncedAt: model.lastSyncedAt,
            rawPayloadFingerprint: model.rawPayloadFingerprint,
            tripID: model.trip?.id,
            cancellationDeadlines: model.cancellationDeadlines.map(deadline(from:)),
            rateDetails: model.rateDetails.map(rateDetails(from:)),
            passengers: model.passengers.map(passenger(from:))
        )
    }

    public static func deadline(from model: SDCancellationDeadline) -> CancellationDeadline {
        CancellationDeadline(
            id: model.id,
            deadlineAt: model.deadlineAt,
            policyText: model.policyText,
            isStrict: model.isStrict,
            isFreeCancellation: model.isFreeCancellation,
            hotelOffsetSeconds: model.hotelOffsetSeconds,
            cancellationFeeAmount: model.cancellationFeeAmount,
            bookingID: model.booking?.id
        )
    }

    public static func rateDetails(from model: SDBookingRateDetails) -> BookingRateDetails {
        BookingRateDetails(
            id: model.id,
            bookingID: model.booking?.id,
            rawDetailsFingerprint: model.rawDetailsFingerprint,
            totalPriceAmount: model.totalPriceAmount,
            totalPriceCurrency: model.totalPriceCurrency,
            roomCategory: model.roomCategory,
            boardType: BookingBoardType(rawValue: model.boardTypeRaw ?? "") ?? .unknown,
            includedBreakfast: model.includedBreakfast,
            guestCount: model.guestCount,
            roomCount: model.roomCount,
            airline: model.airline,
            passengerCount: model.passengerCount,
            baggageInfoRaw: model.baggageInfoRaw,
            roomItems: model.roomItems.map(roomItem(from:)),
            lastParsedAt: model.lastParsedAt
        )
    }

    public static func roomItem(from model: SDBookingRoomItem) -> BookingRoomItem {
        BookingRoomItem(
            id: model.id,
            category: model.category,
            confirmationCode: model.confirmationCode,
            priceAmount: model.priceAmount,
            priceCurrency: model.priceCurrency,
            guestSummary: model.guestSummary,
            externalUrl: model.externalUrl,
            sortIndex: model.sortIndex
        )
    }

    public static func passenger(from model: SDBookingPassenger) -> BookingPassenger {
        BookingPassenger(
            id: model.id,
            bookingID: model.passengerID,
            passengerNumber: model.passengerNumber,
            travellerType: TravellerType(rawValue: model.travellerTypeRaw ?? "") ?? .unknown,
            title: model.title,
            givenName: model.givenName,
            familyName: model.familyName,
            secondFamilyName: model.secondFamilyName,
            birthDate: model.birthDate,
            baggageAllowances: model.baggageAllowances.map(baggageAllowance(from:))
        )
    }

    public static func baggageAllowance(from model: SDBaggageAllowance) -> BaggageAllowance {
        BaggageAllowance(
            id: model.id,
            passengerID: model.passenger?.id,
            type: BaggageType(rawValue: model.baggageTypeRaw) ?? .unknown,
            pieceCount: model.pieceCount,
            weightKg: model.weightKg,
            sectionID: model.sectionID,
            airlineCode: model.airlineCode,
            fromLabel: model.fromLabel,
            toLabel: model.toLabel
        )
    }

    public static func gap(from model: SDGap) -> Gap {
        Gap(
            id: model.id,
            tripID: model.trip?.id,
            fromBookingID: model.fromBooking?.id,
            toBookingID: model.toBooking?.id,
            gapStart: model.gapStart,
            gapEnd: model.gapEnd,
            kind: GapKind(rawValue: model.kindRaw) ?? .both,
            titleOverride: model.titleOverride,
            identityKey: model.identityKey,
            priceAmount: model.priceAmount,
            priceCurrencyCode: model.priceCurrencyCode,
            suggestionStateRaw: model.suggestionStateRaw
        )
    }

    public static func reminder(from model: SDReminder) -> Reminder {
        Reminder(
            id: model.id,
            fireAt: model.fireAt,
            target: ReminderTarget(rawValue: model.targetRaw) ?? .custom,
            channel: ReminderChannel(rawValue: model.channelRaw) ?? .notification,
            status: ReminderStatus(rawValue: model.statusRaw) ?? .scheduled,
            title: model.title,
            notes: model.notes,
            cancellationDeadlineID: model.cancellationDeadline?.id,
            gapID: model.gap?.id,
            externalAlarmId: model.externalAlarmId
        )
    }

    public static func calendarEventLink(from model: SDCalendarEventLink) -> CalendarEventLink {
        CalendarEventLink(
            id: model.id,
            role: CalendarEventRole(rawValue: model.roleRaw) ?? .tripStart,
            ownerTripID: model.ownerTripID,
            ownerBookingID: model.ownerBookingID,
            eventIdentifier: model.eventIdentifier,
            calendarItemExternalIdentifier: model.calendarItemExternalIdentifier,
            lastSyncedAt: model.lastSyncedAt
        )
    }

    public static func cancellationDeadlineLink(from model: SDCancellationDeadlineLink) -> CancellationDeadlineLink {
        CancellationDeadlineLink(
            id: model.id,
            ownerTripID: model.ownerTripID,
            ownerBookingID: model.ownerBookingID,
            cancellationDeadlineID: model.cancellationDeadlineID,
            leadDays: model.leadDays,
            eventIdentifier: model.eventIdentifier,
            reminderIdentifier: model.reminderIdentifier,
            lastSyncedAt: model.lastSyncedAt
        )
    }
}
