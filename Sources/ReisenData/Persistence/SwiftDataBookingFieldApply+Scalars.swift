import Foundation
import SwiftData
import ReisenDomain

extension SwiftDataBookingFieldApply {
    static func applyIdentity(_ booking: Booking, to model: SDBooking) {
        model.providerRaw = booking.provider.rawValue
        model.bookingTypeRaw = booking.bookingType.rawValue
        model.title = booking.title
        model.confirmationCode = booking.confirmationCode
        model.externalUrl = booking.externalUrl
        model.cancellationUrl = booking.cancellationUrl
    }

    static func applyTimes(_ booking: Booking, to model: SDBooking) {
        model.startAt = booking.startAt
        model.endAt = booking.endAt
        model.hotelOffsetSeconds = booking.hotelOffsetSeconds
        model.flightDepartureOffsetSeconds = booking.flightDepartureOffsetSeconds
        model.flightArrivalOffsetSeconds = booking.flightArrivalOffsetSeconds
        model.hotelCheckInMinutes = booking.hotelCheckInMinutes
        model.hotelCheckOutMinutes = booking.hotelCheckOutMinutes
        model.timesSourceFingerprint = booking.timesSourceFingerprint
        model.timesNormalized = booking.timesNormalized
    }

    static func applyLocations(_ booking: Booking, to model: SDBooking) {
        model.locationFrom = booking.locationFrom
        model.locationTo = booking.locationTo
        model.locationFromAddress = booking.locationFromAddress
        model.locationToAddress = booking.locationToAddress
        model.operatorName = booking.operatorName
        model.isAllDay = booking.isAllDay
    }

    static func applyMeta(_ booking: Booking, to model: SDBooking) {
        model.statusRaw = booking.status.rawValue
        model.lastSyncedAt = booking.lastSyncedAt
        model.rawPayloadFingerprint = booking.rawPayloadFingerprint
        model.autoGapIdentityKey = booking.autoGapIdentityKey
    }
}
