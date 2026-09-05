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

@Test("civilDay fromISO: Mitternacht +01:00 → Kalendertag, nicht GMT-Vortag")
func hotelStayDateCivilDayFromISOOffsetMidnight() {
    #expect(
        HotelStayDate.civilDay(fromISO: "1980-01-01T00:00:00+01:00")
            == HotelStayDate.dateOnly(year: 1980, month: 1, day: 1)
    )
    #expect(
        HotelStayDate.civilDay(fromISO: "2015-06-15T00:00:00+01:00")
            == HotelStayDate.dateOnly(year: 2015, month: 6, day: 15)
    )
    #expect(
        HotelStayDate.civilDay(fromISO: "1980-01-01")
            == HotelStayDate.dateOnly(year: 1980, month: 1, day: 1)
    )
    // Instant-Parse ohne Civil-Day würde den GMT-Vortag speichern.
    #expect(
        ISODateTime.parse("1980-01-01T00:00:00+01:00")
            != HotelStayDate.dateOnly(year: 1980, month: 1, day: 1)
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

@Test("Period-Expand Confirm: Proposal-GMT → localPicker → Persist erhält Anker (R16)")
func hotelStayDatePeriodExpandConfirmLocalPickerBeforePersist() {
    let proposalStart = HotelStayDate.dateOnly(year: 2026, month: 8, day: 8)
    let proposalEnd = HotelStayDate.dateOnly(year: 2026, month: 9, day: 8)
    var west = Calendar(identifier: .gregorian)
    west.timeZone = TimeZone(secondsFromGMT: -8 * 3600)!

    let pickerStart = HotelStayDate.localPickerDate(fromStored: proposalStart, calendar: west)
    let pickerEnd = HotelStayDate.localPickerDate(fromStored: proposalEnd, calendar: west)
    #expect(HotelStayDate.dateOnly(fromLocalPickerDate: pickerStart, calendar: west) == proposalStart)
    #expect(HotelStayDate.dateOnly(fromLocalPickerDate: pickerEnd, calendar: west) == proposalEnd)

    // Ohne localPicker: GMT-Anker direkt als Picker-Wert → Persist verschiebt Tag.
    #expect(
        HotelStayDate.dateOnly(fromLocalPickerDate: proposalStart, calendar: west)
            == HotelStayDate.dateOnly(year: 2026, month: 8, day: 7)
    )
}

@Test("Assignment-Preview: Trip aus Picker via dateOnly (east of GMT) trifft Buchungsfenster")
func hotelStayDateAssignPreviewTripFromLocalPickerPreservesWindow() {
    var east = Calendar(identifier: .gregorian)
    east.timeZone = TimeZone(secondsFromGMT: 12 * 3600)!
    let pickerStart = east.date(from: DateComponents(year: 2026, month: 9, day: 5))!
    let pickerEnd = east.date(from: DateComponents(year: 2026, month: 9, day: 10))!
    // Letzter Trip-Tag: ohne Konvertierung endet das Fenster in GMT schon am 9.
    let bookingOnTrueEnd = HotelStayDate.dateOnly(year: 2026, month: 9, day: 10)

    let mixedTrip = Trip(title: "", startDate: pickerStart, endDate: pickerEnd)
    #expect(
        !TripBookingDateWindow.contains(
            bookingStart: bookingOnTrueEnd,
            bookingEnd: bookingOnTrueEnd,
            tripStart: mixedTrip.startDate,
            tripEnd: mixedTrip.endDate
        )
    )

    let anchoredTrip = Trip(
        title: "",
        startDate: HotelStayDate.dateOnly(fromLocalPickerDate: pickerStart, calendar: east),
        endDate: HotelStayDate.dateOnly(fromLocalPickerDate: pickerEnd, calendar: east)
    )
    #expect(
        TripBookingDateWindow.contains(
            bookingStart: bookingOnTrueEnd,
            bookingEnd: bookingOnTrueEnd,
            tripStart: anchoredTrip.startDate,
            tripEnd: anchoredTrip.endDate
        )
    )
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
