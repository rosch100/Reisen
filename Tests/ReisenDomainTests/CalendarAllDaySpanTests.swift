import Testing
import Foundation
import ReisenDomain

@Test("Hotel-All-day: Buchungs-Tagesdaten 11.–14. → EventKit start=11., end=14. (inklusiv, kein +1)")
func hotelAllDaySpanMatchesBookingDaysExactly() {
    let start = HotelStayDate.dateOnly(year: 2026, month: 8, day: 11)
    let end = HotelStayDate.dateOnly(year: 2026, month: 8, day: 14)

    let span = CalendarAllDaySpan.hotelStayRange(
        startDateOnly: start,
        endDateOnlyInclusive: end
    )

    #expect(span.startDay.day == 11)
    #expect(span.endDayInclusive.day == 14)

    let cal = Calendar.current
    #expect(cal.component(.day, from: span.start) == 11)
    #expect(cal.component(.day, from: span.end) == 14)
    #expect(cal.dateComponents([.day], from: span.start, to: span.end).day == 3)
}

@Test("Ein-Tages-All-day: Start und Ende sind derselbe Tag")
func singleDayAllDayHasIdenticalStartAndEnd() {
    let span = CalendarAllDaySpan.range(
        startDay: DateComponents(year: 2026, month: 8, day: 1),
        endDayInclusive: DateComponents(year: 2026, month: 8, day: 1)
    )
    #expect(Calendar.current.isDate(span.start, inSameDayAs: span.end))
}
