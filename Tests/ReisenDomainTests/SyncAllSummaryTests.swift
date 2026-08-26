import Testing
import ReisenDomain

@Test func syncAllSummary_statusLine_countsSuccessAndFailure() {
    #expect(SyncAllSummary.statusLine(successCount: 1, failureCount: 3)
        == "Sync beendet: 1 ok, 3 fehlgeschlagen.")
}

@Test func syncAllSummary_errorDetails_listsEveryProviderReason() {
    let details = SyncAllSummary.errorDetails(failures: [
        (providerName: "Check24", message: "Keine Buchungsdaten (Start/Ende) konnten im Snapshot gefunden werden."),
        (providerName: "Opodo", message: "Keine Opodo-Buchungen im HTML gefunden."),
        (providerName: "Booking.com", message: "Navigation-Timeout für https://secure.booking.com/mytrips.de.html"),
    ])

    #expect(details == """
        Check24: Keine Buchungsdaten (Start/Ende) konnten im Snapshot gefunden werden.
        Opodo: Keine Opodo-Buchungen im HTML gefunden.
        Booking.com: Navigation-Timeout für https://secure.booking.com/mytrips.de.html
        """)
}

@Test func providerID_displayNames_matchProductLabels() {
    #expect(ProviderID.check24.displayName == "Check24")
    #expect(ProviderID.opodo.displayName == "Opodo")
    #expect(ProviderID.booking.displayName == "Booking.com")
    #expect(ProviderID.airbnb.displayName == "Airbnb")
    #expect(ProviderID.getYourGuide.displayName == "GetYourGuide")
    #expect(ProviderID.manual.displayName == "Manuell")
}
