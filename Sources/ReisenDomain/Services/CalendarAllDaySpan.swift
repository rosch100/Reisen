import Foundation

/// All-day-Spannen für EventKit aus **reinen Kalendertagen** (Y/M/D).
///
/// Evidenz (macOS Calendar + EventKit, gemessen am Live-Kalender „Reisen“):
/// Bei `isAllDay = true` ist `endDate` der **letzte inklusive** Tag
/// (Calendar zeigt z. B. `… 23:59:59` dieses Tages). Ein iCal-mäßiges `+1 Tag`
/// (exklusives Ende) macht den Termin in der Praxis **einen Tag zu lang**
/// (Buchung 11.–14. → Kalender 11.–15.).
///
/// Deshalb: `endDate` = Buchungs-Endtag (inkl.), nicht Tag danach.
/// Bau der Instants mit `Calendar.current` + `DateComponents` (WWDC23).
public enum CalendarAllDaySpan: Sendable {
    public struct Range: Equatable, Sendable {
        public let start: Date
        public let end: Date
        public let startDay: DateComponents
        public let endDayInclusive: DateComponents

        public init(
            start: Date,
            end: Date,
            startDay: DateComponents,
            endDayInclusive: DateComponents
        ) {
            self.start = start
            self.end = end
            self.startDay = startDay
            self.endDayInclusive = endDayInclusive
        }
    }

    /// Hotel: exakt die Buchungs-Tagesdaten (Start-Tag … End-Tag, beide inklusiv).
    public static func hotelStayRange(
        startDateOnly: Date,
        endDateOnlyInclusive: Date
    ) -> Range {
        let startDay = HotelStayDate.calendar.dateComponents(
            [.year, .month, .day],
            from: HotelStayDate.dateOnly(fromStoredOrParsed: startDateOnly)
        )
        let endDay = HotelStayDate.calendar.dateComponents(
            [.year, .month, .day],
            from: HotelStayDate.dateOnly(fromStoredOrParsed: endDateOnlyInclusive)
        )
        return range(startDay: startDay, endDayInclusive: endDay)
    }

    /// Allgemeine All-day-Spanne: Y/M/D aus `civilTimeZone`, EventKit-Bau mit `Calendar.current`.
    public static func eventKitRange(
        startInstant: Date,
        endInstantInclusive: Date,
        civilTimeZone: TimeZone
    ) -> Range {
        var civil = Calendar(identifier: .gregorian)
        civil.timeZone = civilTimeZone
        let startDay = civil.dateComponents([.year, .month, .day], from: startInstant)
        let endDay = civil.dateComponents([.year, .month, .day], from: endInstantInclusive)
        return range(startDay: startDay, endDayInclusive: endDay)
    }

    /// - Important: `endDayInclusive` ist der **letzte sichtbare** Kalendertag.
    public static func range(
        startDay: DateComponents,
        endDayInclusive: DateComponents,
        eventKitCalendar: Calendar = .current
    ) -> Range {
        guard
            let start = eventKitCalendar.date(from: DateComponents(
                year: startDay.year,
                month: startDay.month,
                day: startDay.day
            )),
            let end = eventKitCalendar.date(from: DateComponents(
                year: endDayInclusive.year,
                month: endDayInclusive.month,
                day: endDayInclusive.day
            ))
        else {
            preconditionFailure("CalendarAllDaySpan: Y/M/D müssen ein gültiges Datum ergeben")
        }
        return Range(
            start: start,
            end: end,
            startDay: DateComponents(year: startDay.year, month: startDay.month, day: startDay.day),
            endDayInclusive: DateComponents(
                year: endDayInclusive.year,
                month: endDayInclusive.month,
                day: endDayInclusive.day
            )
        )
    }
}
