import Foundation

public enum SyncBookingDraftOffsets {
    public static func apply(from draft: ProviderBookingDraft, onto booking: inout Booking) {
        booking.hotelOffsetSeconds = draft.hotelOffsetSeconds ?? booking.hotelOffsetSeconds
        booking.hotelCheckInMinutes = draft.hotelCheckInMinutes ?? booking.hotelCheckInMinutes
        booking.hotelCheckOutMinutes = draft.hotelCheckOutMinutes ?? booking.hotelCheckOutMinutes
        booking.flightDepartureOffsetSeconds = draft.flightDepartureOffsetSeconds ?? booking.flightDepartureOffsetSeconds
        booking.flightArrivalOffsetSeconds = draft.flightArrivalOffsetSeconds ?? booking.flightArrivalOffsetSeconds
    }
}
