import Foundation
import Testing
import ReisenDomain

@Test func l10n_allKeysResolveInGerman() {
    L10n.withLocale(Locale(identifier: "de")) {

    for key in L10nKey.allCases {
        let value = L10n.string(key)
        #expect(!value.isEmpty, "Key \(key.rawValue) liefert leeren String")
        #expect(value != key.rawValue, "Key \(key.rawValue) wurde nicht übersetzt")
    }
    }
}

@Test func l10n_allKeysResolveInEnglish() {
    L10n.withLocale(Locale(identifier: "en")) {

    for key in L10nKey.allCases {
        let value = L10n.string(key)
        #expect(!value.isEmpty, "Key \(key.rawValue) liefert leeren String in EN")
        #expect(value != key.rawValue, "Key \(key.rawValue) wurde nicht übersetzt in EN")
    }
    }
}

@Test func l10n_overlapLabel_namesPartnersWithoutCountBadge() {
    L10n.withLocale(Locale(identifier: "de")) {

    #expect(L10n.overlapLabel(partnerTitles: []) == L10n.string(.bookingOverlap))
    #expect(L10n.overlapLabel(partnerTitles: ["Hotel A"]) == L10n.format(.bookingOverlapWithPartner, "Hotel A"))
    #expect(
        L10n.overlapLabel(partnerTitles: ["Hotel A", "Flug B"])
            == L10n.format(.bookingOverlapWithTwoPartners, "Hotel A", "Flug B")
    )
    let many = L10n.overlapLabel(partnerTitles: ["Hotel A", "Flug B", "Tour C"])
    #expect(many == L10n.format(.bookingOverlapWithPartnerAndOthers, "Hotel A", 2))
    #expect(!many.contains("+"))
    }
}

@Test func l10n_tripCompletenessGapCount_plural() {
    L10n.withLocale(Locale(identifier: "de")) {

    #expect(L10n.tripCompletenessGapCount(1) == L10n.string(.tripCompletenessGapOne))
    #expect(L10n.tripCompletenessGapCount(3) == L10n.format(.tripCompletenessGapMany, 3))
    #expect(L10n.tripCompletenessKindCaption(kinds: [.both]) == nil)
    #expect(L10n.tripCompletenessKindCaption(kinds: [.lodging, .transport]) == "\(L10n.gapKindDisplay(.lodging)) · \(L10n.gapKindDisplay(.transport))")
    }
}

@Test func l10n_deCopyClarity_terminologySSOT() {
    L10n.withLocale(Locale(identifier: "de")) {
        #expect(L10n.string(.baggageShortPersonal) == "Persönlich")
        #expect(L10n.format(.baggagePassengerLine, 1, "Hand") == "Passagier 1: Hand")
        #expect(L10n.string(.bookingCancellationLocked) == "Nicht mehr kostenlos stornierbar")
        #expect(L10n.format(.sync_resultNoDeadlines, 3) == "Keine Stornofristen gefunden (3 Buchungen).")
        #expect(L10n.string(.actionAssignToTrip) == "Einer Reise zuordnen…")
        #expect(L10n.string(.commonSave) == "Speichern")
        #expect(L10n.string(.credentialPassword) == "Passwort")
        #expect(L10n.string(.menuProviderSync) == "Portal-Sync")
        #expect(L10n.string(.settingsTripTimesToggle) == "Reisebeginn und -ende eintragen")
        #expect(L10n.string(.settingsFlightTimesToggle) == "Abflug und Ankunft eintragen")
        #expect(L10n.string(.actionCopyConfirmation) == "Buchungsnummer kopieren")
        #expect(L10n.string(.bookingDetailConfirmationNumber) == "Buchungsnummer")
        #expect(L10n.string(.editorSyncOverwriteWarning) == "Änderungen können bei der nächsten Synchronisation überschrieben werden.")
        #expect(L10n.string(.syncError) == "Synchronisationsfehler")
        #expect(L10n.string(.syncAllFinished) == "Synchronisation beendet.")
        #expect(L10n.string(.settingsIcloudDisableMessage).hasPrefix("Die Synchronisation stoppt"))
        #expect(L10n.string(.settingsIcloudStatusUserDisabled).hasPrefix("iCloud-Synchronisation ist"))
        #expect(L10n.string(.bookingDeleteConfirmMessageSynced).contains("Portal-Synchronisation"))
        #expect(L10n.string(.tripDeleteConfirmMessageWithBookings).contains("nächsten Synchronisation"))
        #expect(L10n.string(.tabSync) == "Sync")
        #expect(L10n.string(.settingsIcloudDisableTitle) == "iCloud-Sync ausschalten?")
        #expect(L10n.string(.settingsIcloudDisableKeepLocal) == "Nur Sync stoppen")
        #expect(L10n.string(.actionResetLocalStores) == "Lokale Daten zurücksetzen…")
        #expect(L10n.string(.tripTimeline) == "Zeitachse")
        #expect(L10n.string(.bookingDeleteConfirmMessage).contains("Voyenna"))
        #expect(L10n.string(.tabTrips) == "Reisen")
        #expect(!L10n.string(.actionOpenPasswords).localizedCaseInsensitiveContains("Passwords"))
        #expect(L10n.string(.actionOpenPasswords) == "Passwörter öffnen")
    }
}
