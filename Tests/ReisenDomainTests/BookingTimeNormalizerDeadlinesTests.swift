import Testing
import Foundation
import ReisenDomain

@Test("BookingTimeNormalizer belässt Deadline-hotelOffsetSeconds nil ohne Booking-Offset")
func bookingTimeNormalizerLeavesDeadlineOffsetNilWhenBookingHasNone() throws {
    let rawStartAt = Date(timeIntervalSince1970: 1_780_000_000)
    let rawEndAt = Date(timeIntervalSince1970: 1_780_010_000)
    let rawDeadlineAt = Date(timeIntervalSince1970: 1_780_020_000)

    let deadline = CancellationDeadline(
        deadlineAt: rawDeadlineAt,
        policyText: "Stornierungsrichtlinie",
        isStrict: true,
        isFreeCancellation: true,
        hotelOffsetSeconds: nil
    )

    var booking = Booking(
        provider: .opodo,
        bookingType: .hotel,
        startAt: rawStartAt,
        endAt: rawEndAt,
        hotelOffsetSeconds: nil,
        hotelCheckInMinutes: 14 * 60,
        hotelCheckOutMinutes: 12 * 60,
        cancellationDeadlines: [deadline]
    )
    booking.timesNormalized = false

    let normalized = BookingTimeNormalizer().normalizePendingIfPossible(booking)
    let gmt = HotelStayDate.calendar
    let startComps = gmt.dateComponents([.hour, .minute], from: normalized.startAt)
    let endComps = gmt.dateComponents([.hour, .minute], from: normalized.endAt)
    #expect(startComps.hour == 0)
    #expect(startComps.minute == 0)
    #expect(endComps.hour == 0)
    #expect(endComps.minute == 0)
    #expect(normalized.startAt == HotelStayDate.dateOnly(fromStoredOrParsed: rawStartAt))
    #expect(normalized.endAt == HotelStayDate.dateOnly(fromStoredOrParsed: rawEndAt))
    #expect(normalized.timesNormalized == true)

    #expect(normalized.cancellationDeadlines.count == 1)
    let normalizedDeadline = try #require(normalized.cancellationDeadlines.first)
    #expect(normalizedDeadline.hotelOffsetSeconds == nil)
}

@Test("BookingTimeNormalizer propagiert Booking hotelOffsetSeconds auf Deadlines")
func bookingTimeNormalizerPropagatesBookingOffsetToDeadlines() {
    let rawStartAt = Date(timeIntervalSince1970: 1_780_000_000)
    let rawEndAt = Date(timeIntervalSince1970: 1_780_010_000)
    let rawDeadlineAt = Date(timeIntervalSince1970: 1_780_020_000)

    let deadline = CancellationDeadline(
        deadlineAt: rawDeadlineAt,
        policyText: "Stornierungsrichtlinie",
        isStrict: true,
        isFreeCancellation: true,
        hotelOffsetSeconds: nil
    )

    var booking = Booking(
        provider: .opodo,
        bookingType: .hotel,
        startAt: rawStartAt,
        endAt: rawEndAt,
        hotelOffsetSeconds: 2 * 3600,
        hotelCheckInMinutes: 14 * 60,
        hotelCheckOutMinutes: 12 * 60,
        cancellationDeadlines: [deadline]
    )
    booking.timesNormalized = false

    let normalized = BookingTimeNormalizer().normalizePendingIfPossible(booking)
    let normalizedDeadline = normalized.cancellationDeadlines.first
    #expect(normalizedDeadline?.hotelOffsetSeconds == 2 * 3600)
}

@Test("BookingTimeNormalizer normalisiert train mit Offsets wie Flug")
func bookingTimeNormalizerNormalizesTrainWithOffsets() {
    let rawStartAt = Date(timeIntervalSince1970: 1_780_000_000)
    let rawEndAt = Date(timeIntervalSince1970: 1_780_010_000)

    var booking = Booking(
        provider: .manual,
        bookingType: .train,
        startAt: rawStartAt,
        endAt: rawEndAt,
        flightDepartureOffsetSeconds: 3600,
        flightArrivalOffsetSeconds: 7200
    )
    booking.timesNormalized = false

    let normalized = BookingTimeNormalizer().normalizePendingIfPossible(booking)
    #expect(normalized.startAt == rawStartAt.addingTimeInterval(-3600))
    #expect(normalized.endAt == rawEndAt.addingTimeInterval(-7200))
    #expect(normalized.timesNormalized == true)
}

@Test("BookingTimeNormalizer propagiert Flug-Abflug-Offset auf Deadlines")
func bookingTimeNormalizerPropagatesFlightDepartureOffsetToDeadlines() {
    let rawStartAt = Date(timeIntervalSince1970: 1_780_000_000)
    let rawEndAt = Date(timeIntervalSince1970: 1_780_010_000)
    let rawDeadlineAt = Date(timeIntervalSince1970: 1_780_020_000)

    let deadline = CancellationDeadline(
        deadlineAt: rawDeadlineAt,
        policyText: "Free cancel",
        isStrict: true,
        isFreeCancellation: true,
        hotelOffsetSeconds: nil
    )

    var booking = Booking(
        provider: .booking,
        bookingType: .flight,
        startAt: rawStartAt,
        endAt: rawEndAt,
        flightDepartureOffsetSeconds: 7 * 3600,
        flightArrivalOffsetSeconds: 8 * 3600,
        cancellationDeadlines: [deadline]
    )
    booking.timesNormalized = false

    let normalized = BookingTimeNormalizer().normalizePendingIfPossible(booking)
    #expect(normalized.cancellationDeadlines.first?.hotelOffsetSeconds == 7 * 3600)
}

@Test("BookingTimeNormalizer belässt Deadline-Offset nil bei Flug ohne Offsets")
func bookingTimeNormalizerLeavesFlightDeadlineOffsetNilWithoutFlightOffsets() {
    let deadline = CancellationDeadline(
        deadlineAt: Date(timeIntervalSince1970: 1_780_020_000),
        hotelOffsetSeconds: nil
    )
    var booking = Booking(
        provider: .booking,
        bookingType: .flight,
        startAt: Date(timeIntervalSince1970: 1_780_000_000),
        endAt: Date(timeIntervalSince1970: 1_780_010_000),
        cancellationDeadlines: [deadline]
    )
    booking.timesNormalized = false
    let normalized = BookingTimeNormalizer().normalizePendingIfPossible(booking)
    #expect(normalized.cancellationDeadlines.first?.hotelOffsetSeconds == nil)
}
