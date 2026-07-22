import Testing
import Foundation
import ReisenDomain

@Test("BookingTimeNormalizer setzt Deadline-hotelOffsetSeconds vor Persistenz (Default 0)")
func bookingTimeNormalizerSetsDeadlineOffsetDefaultZero() {
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

    let normalizedDeadline = normalized.cancellationDeadlines.first
    #expect(normalizedDeadline?.hotelOffsetSeconds == 0)
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
