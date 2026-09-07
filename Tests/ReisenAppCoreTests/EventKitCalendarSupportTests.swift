import Testing
@testable import ReisenAppCore
import ReisenDomain
@preconcurrency import EventKit

@Suite("EventKitCalendarSupport")
struct EventKitCalendarSupportTests {
    @Test func title_fixed_usesEventOrReminderTitle() {
        let trip = Trip(
            title: "Trip",
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 1)
        )
        #expect(
            EventKitCalendarSupport.title(
                for: trip,
                kind: .event,
                calendarTitleMode: .fixed,
                eventCalendarTitle: "Events",
                reminderCalendarTitle: "Reminders"
            ) == "Events"
        )
        #expect(
            EventKitCalendarSupport.title(
                for: trip,
                kind: .reminder,
                calendarTitleMode: .fixed,
                eventCalendarTitle: "Events",
                reminderCalendarTitle: "Reminders"
            ) == "Reminders"
        )
    }

    @Test func title_tripTitle_usesTripTitle() {
        let trip = Trip(
            title: "Island Hop",
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 1)
        )
        #expect(
            EventKitCalendarSupport.title(
                for: trip,
                kind: .event,
                calendarTitleMode: .tripTitle,
                eventCalendarTitle: "Events",
                reminderCalendarTitle: "Reminders"
            ) == "Island Hop"
        )
    }
}
