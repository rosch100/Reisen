import Foundation
import Testing
@testable import ReisenProviders

@Test func loginAssistanceSchedulesOncePerURL() {
    var tracker = LoginAssistanceTracker()
    let loginURL = URL(string: "https://kundenbereich.check24.de/login")!
    let nextURL = URL(string: "https://kundenbereich.check24.de/login/step")!

    let firstSchedule = tracker.shouldSchedule(for: loginURL)
    let repeatedSchedule = tracker.shouldSchedule(for: loginURL)
    let nextPageSchedule = tracker.shouldSchedule(for: nextURL)

    #expect(firstSchedule)
    #expect(!repeatedSchedule)
    #expect(nextPageSchedule)

    tracker.reset()
    let rescheduled = tracker.shouldSchedule(for: loginURL)
    #expect(rescheduled)
}
