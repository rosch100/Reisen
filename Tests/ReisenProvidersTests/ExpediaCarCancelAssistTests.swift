import Foundation
import Testing
import ReisenDomain
import ReisenProviders

@Test func expediaCarCancelAssist_shouldRunOnlyOnManageBookingForCar() {
    let manage = URL(
        string: "https://www.expedia.de/trips/egti-TEST-VIEW-0001/details/abc/manage-booking"
    )
    let detail = URL(string: "https://www.expedia.de/trips/egti-TEST-VIEW-0001/details/abc")
    let other = URL(string: "https://www.booking.com/manage-booking")
    #expect(ExpediaCarCancelAssist.isManageBookingURL(manage))
    #expect(!ExpediaCarCancelAssist.isManageBookingURL(detail))
    #expect(!ExpediaCarCancelAssist.isManageBookingURL(other))
    #expect(
        ExpediaCarCancelAssist.shouldRun(
            provider: .expedia,
            loadedURL: manage,
            bookingType: .carRental
        )
    )
    #expect(
        !ExpediaCarCancelAssist.shouldRun(
            provider: .expedia,
            loadedURL: manage,
            bookingType: .flight
        )
    )
    #expect(
        !ExpediaCarCancelAssist.shouldRun(
            provider: .expedia,
            loadedURL: manage,
            bookingType: .hotel
        )
    )
    #expect(
        !ExpediaCarCancelAssist.shouldRun(
            provider: .expedia,
            loadedURL: detail,
            bookingType: .carRental
        )
    )
    #expect(
        !ExpediaCarCancelAssist.shouldRun(
            provider: .opodo,
            loadedURL: manage,
            bookingType: .carRental
        )
    )
}

@Test func expediaCarCancelAssistScript_usesGermanHARSelectorsAndRequiresCarMarker() {
    #expect(ExpediaCarCancelAssistScript.parseStepStatus("clicked_entry") == .clickedEntry)
    #expect(ExpediaCarCancelAssistScript.parseStepStatus("clicked_confirm") == .clickedConfirm)
    #expect(ExpediaCarCancelAssistScript.parseStepStatus("not_car_cancel") == .notCarCancel)
    #expect(ExpediaCarCancelAssistScript.parsePollStatus("dialog_open") == .dialogOpen)
    #expect(ExpediaCarCancelAssistScript.parsePollStatus("dialog_gone") == .dialogGone)
    #expect(ExpediaCarCancelAssistScript.step.contains("Buchung\\s+stornieren"))
    #expect(ExpediaCarCancelAssistScript.step.contains("Ja,\\s*jetzt\\s*stornieren"))
    #expect(ExpediaCarCancelAssistScript.step.contains("TripsCancelCarAction"))
    #expect(ExpediaCarCancelAssistScript.step.contains("if (!isCar) return 'not_car_cancel'"))
    #expect(ExpediaCarCancelAssistScript.poll.contains("Nein,\\s*nicht\\s*stornieren"))
    #expect(ExpediaCarCancelAssistScript.step.contains(ExpediaCarCancelAssist.portalHost))

    let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("docs/fixtures/provider-research/expedia_manage_booking_cancel_car_redacted.html")
    let html = try? String(contentsOf: fixtureURL, encoding: .utf8)
    #expect(html?.contains("Buchung stornieren") == true)
    #expect(html?.contains("Ja, jetzt stornieren") == true)
    #expect(html?.contains("TripsCancelCarAction") == true)
}
