import Testing
import Foundation
import ReisenDomain

@Test("HotelStayDate calendarDay nutzt Hotel-TZ, sonst GMT-Anker")
func hotelStayDateCalendarDayFromParsedUsesOffset() {
    let utcEvening = Date(timeIntervalSince1970: 1_775_340_000) // 2026-04-04T22:00:00Z
    #expect(
        HotelStayDate.calendarDay(fromParsed: utcEvening, offsetSeconds: 2 * 3600)
            == HotelStayDate.dateOnly(year: 2026, month: 4, day: 5)
    )
    #expect(
        HotelStayDate.calendarDay(fromParsed: utcEvening)
            == HotelStayDate.dateOnly(year: 2026, month: 4, day: 4)
    )
}

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

@Test("HotelStayDate.parseGerman liest dd.MM.yyyy als GMT-Anker")
func hotelStayDateParseGermanIsGMTAnchor() {
    #expect(HotelStayDate.parseGerman("11.08.2026") == HotelStayDate.dateOnly(year: 2026, month: 8, day: 11))
    #expect(HotelStayDate.parseGerman(" 11.08.2026 ") == HotelStayDate.dateOnly(year: 2026, month: 8, day: 11))
    #expect(HotelStayDate.parseGerman("2026-08-11") == nil)
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

@Test("localPickerDate Round-Trip Los Angeles und Berlin erhält GMT-Anker")
func hotelStayDateLocalPickerRoundTripLosAngelesAndBerlin() {
    let stored = HotelStayDate.dateOnly(year: 2026, month: 9, day: 5)

    var losAngeles = Calendar(identifier: .gregorian)
    losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let laPicker = HotelStayDate.localPickerDate(fromStored: stored, calendar: losAngeles)
    #expect(
        HotelStayDate.dateOnly(fromLocalPickerDate: laPicker, calendar: losAngeles) == stored
    )

    var berlin = Calendar(identifier: .gregorian)
    berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
    let berlinPicker = HotelStayDate.localPickerDate(fromStored: stored, calendar: berlin)
    #expect(
        HotelStayDate.dateOnly(fromLocalPickerDate: berlinPicker, calendar: berlin) == stored
    )
}

@Test("West of GMT: open→save ohne Edit verschiebt Kalendertag nicht")
func hotelStayDateWestOfGMTOpenSaveDoesNotShiftDay() {
    let stored = HotelStayDate.dateOnly(year: 2026, month: 9, day: 5)
    var west = Calendar(identifier: .gregorian)
    west.timeZone = TimeZone(secondsFromGMT: -8 * 3600)!

    // Ohne Inverse: DatePicker an GMT-Anker binden und speichern verschiebt den Tag.
    #expect(
        HotelStayDate.dateOnly(fromLocalPickerDate: stored, calendar: west)
            == HotelStayDate.dateOnly(year: 2026, month: 9, day: 4)
    )

    let picker = HotelStayDate.localPickerDate(fromStored: stored, calendar: west)
    #expect(HotelStayDate.dateOnly(fromLocalPickerDate: picker, calendar: west) == stored)
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
