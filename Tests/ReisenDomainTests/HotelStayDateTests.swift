import Testing
import Foundation
import ReisenDomain

@Test("HotelStayDate verwirft Uhrzeit und speichert GMT-Datumsanker")
func hotelStayDateStripsTimeToGMTAnchor() {
    let withTime = HotelStayDate.parse("2026-08-11T14:30:00+07:00")
    #expect(withTime == HotelStayDate.dateOnly(year: 2026, month: 8, day: 11))

    let gmt = HotelStayDate.calendar
    let comps = gmt.dateComponents([.year, .month, .day, .hour, .minute], from: withTime!)
    #expect(comps.year == 2026)
    #expect(comps.month == 8)
    #expect(comps.day == 11)
    #expect(comps.hour == 0)
    #expect(comps.minute == 0)
}

@Test("HotelStayDate stellt Legacy-Hotel-Mitternacht wieder her, ohne TZ in der Semantik zu behalten")
func hotelStayDateRecoversLegacyHotelMidnightThenStoresDateOnly() {
    let hotelTZ = TimeZone(secondsFromGMT: 8 * 3600)!
    var hotelCal = Calendar(identifier: .gregorian)
    hotelCal.timeZone = hotelTZ
    let legacyMidnight = hotelCal.date(from: DateComponents(year: 2026, month: 8, day: 11))!

    // Legacy-Instant liegt in GMT noch am 10. — Date-only muss trotzdem 11. ergeben.
    let gmt = HotelStayDate.calendar
    #expect(gmt.component(.day, from: legacyMidnight) == 10)

    let recovered = HotelStayDate.dateOnly(
        fromStoredOrParsed: legacyMidnight,
        legacyHotelOffsetSeconds: 8 * 3600
    )
    #expect(recovered == HotelStayDate.dateOnly(year: 2026, month: 8, day: 11))
    #expect(HotelStayDate.format(recovered, dateFormat: "d.M.yyyy") == "11.8.2026")
}

@Test("DatePicker-Lokalmitternacht wird zum gleichen Kalendertag-Anker")
func hotelStayDateFromLocalPickerPreservesCivilDay() {
    var berlin = Calendar(identifier: .gregorian)
    berlin.timeZone = TimeZone(secondsFromGMT: 2 * 3600)!
    let picker = berlin.date(from: DateComponents(year: 2026, month: 8, day: 11))!

    let stored = HotelStayDate.dateOnly(fromLocalPickerDate: picker, calendar: berlin)
    #expect(stored == HotelStayDate.dateOnly(year: 2026, month: 8, day: 11))
}

@Test("BookingTimeNormalizer kanonisiert Hotels immer auf Date-only (auch wenn schon normalized)")
func bookingTimeNormalizerAlwaysCanonicalizesHotelDates() {
    let hotelTZ = TimeZone(secondsFromGMT: 7 * 3600)!
    var hotelCal = Calendar(identifier: .gregorian)
    hotelCal.timeZone = hotelTZ
    let legacyStart = hotelCal.date(from: DateComponents(year: 2026, month: 8, day: 21))!
    let legacyEnd = hotelCal.date(from: DateComponents(year: 2026, month: 8, day: 24))!

    var booking = Booking(
        provider: .check24,
        bookingType: .hotel,
        startAt: legacyStart,
        endAt: legacyEnd,
        hotelOffsetSeconds: 7 * 3600
    )
    booking.timesNormalized = true

    let normalized = BookingTimeNormalizer().normalizePendingIfPossible(booking)
    #expect(normalized.startAt == HotelStayDate.dateOnly(year: 2026, month: 8, day: 21))
    #expect(normalized.endAt == HotelStayDate.dateOnly(year: 2026, month: 8, day: 24))
}
