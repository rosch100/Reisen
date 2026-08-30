import Foundation
import ReisenDomain

extension DomainMapper {
    public static func booking(from model: SDBooking) -> Booking {
        Booking(
            id: model.id,
            provider: ProviderID(rawValue: model.providerRaw),
            bookingType: BookingType(rawValue: model.bookingTypeRaw) ?? .other,
            title: model.title,
            confirmationCode: model.confirmationCode,
            externalUrl: model.externalUrl,
            cancellationUrl: model.cancellationUrl,
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
            operatorName: model.operatorName,
            isAllDay: model.isAllDay,
            status: BookingStatus(rawValue: model.statusRaw) ?? .unknown,
            lastSyncedAt: model.lastSyncedAt,
            rawPayloadFingerprint: model.rawPayloadFingerprint,
            tripID: model.trip?.id,
            cancellationDeadlines: (model.cancellationDeadlines ?? []).map(deadline(from:)),
            rateDetails: model.rateDetails.map(rateDetails(from:)),
            passengers: (model.passengers ?? []).map(passenger(from:)),
            guestHints: (model.guestHints ?? []).map(guestHint(from:))
        )
    }

    public static func guestHint(from model: SDBookingGuestHint) -> BookingGuestHint {
        BookingGuestHint(
            id: model.id,
            bookingID: model.bookingID ?? model.booking?.id,
            category: GuestHintCategory(rawValue: model.categoryRaw) ?? .preTravelImportant,
            title: model.title,
            detail: model.detail,
            sourceKey: model.sourceKey,
            providerRaw: model.providerRaw
        )
    }
}
