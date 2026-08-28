import Foundation
import Testing
import ReisenDomain
import ReisenSharedUI

private let presentationLocale = Locale(identifier: "de")
private let presentationStart = Date(timeIntervalSince1970: 1_800_000_000)

private func candidate(match: PasteImportMatch) -> PasteImportCandidate {
    PasteImportCandidate(
        draft: PasteImportDraft(
            bookingType: .hotel,
            startAt: presentationStart,
            endAt: presentationStart.addingTimeInterval(86_400),
            endAtIsPlaceholder: false,
            title: "Hotel Lissabon",
            status: .unknown
        ),
        match: match
    )
}

@MainActor
@Test func pasteImportCandidatePresentation_badgeTextDistinguishesNewFromEnrich() {
    L10n.locale = presentationLocale
    defer { L10n.locale = .current }

    let existing = Booking(
        provider: .check24,
        bookingType: .hotel,
        startAt: presentationStart,
        endAt: presentationStart.addingTimeInterval(86_400)
    )

    let new = PasteImportCandidatePresentation(candidate: candidate(match: .none))
    let enrich = PasteImportCandidatePresentation(candidate: candidate(match: .unique(existing)))

    #expect(new.badgeText == L10n.string(.pasteImportBadgeNew))
    #expect(enrich.badgeText == L10n.string(.pasteImportBadgeEnrich))
    #expect(new.badgeText != enrich.badgeText)
    #expect(new.accessibilityLabel == new.badgeText)
    #expect(enrich.accessibilityLabel == enrich.badgeText)
}

@MainActor
@Test func pasteImportCandidatePresentation_ambiguousAddsHintOnly() {
    L10n.locale = presentationLocale
    defer { L10n.locale = .current }

    let ambiguous = PasteImportCandidatePresentation(candidate: candidate(match: .ambiguous))
    let new = PasteImportCandidatePresentation(candidate: candidate(match: .none))

    #expect(ambiguous.badgeText == L10n.string(.pasteImportBadgeNew))
    #expect(ambiguous.ambiguousHint == L10n.string(.pasteImportAmbiguousHint))
    #expect(new.ambiguousHint == nil)
}

@MainActor
@Test func pasteImportCandidatePresentation_titleFallsBackToBookingType() {
    L10n.locale = presentationLocale
    defer { L10n.locale = .current }

    var untitled = candidate(match: .none)
    untitled.draft.title = nil

    #expect(PasteImportCandidatePresentation(candidate: untitled).title == BookingType.hotel.defaultDisplayTitle)
    #expect(PasteImportCandidatePresentation(candidate: candidate(match: .none)).title == "Hotel Lissabon")
}

@MainActor
@Test func pasteImportCandidatePresentation_actionDisabledOnlyWhenModelUnavailable() {
    L10n.locale = presentationLocale
    defer { L10n.locale = .current }

    let unavailable = PasteImportActionPresentation(kind: .unavailable)
    let onDevice = PasteImportActionPresentation(kind: .onDevice)
    let pcc = PasteImportActionPresentation(kind: .privateCloudCompute)

    #expect(unavailable.isEnabled == false)
    #expect(onDevice.isEnabled)
    #expect(pcc.isEnabled)

    #expect(onDevice.label == L10n.string(.menuPasteBooking))
    #expect(onDevice.accessibilityLabel == L10n.string(.menuPasteBooking))
    #expect(unavailable.accessibilityLabel.contains(L10n.string(.menuPasteBooking)))
    #expect(unavailable.accessibilityLabel.contains(L10n.string(.pasteImportUnavailable)))
}

/// Während des Laufs muss sichtbar sein, ob das Material das Gerät verlässt.
@MainActor
@Test func pasteImportProgressPresentation_namesTheRunningModelKind() {
    L10n.locale = presentationLocale
    defer { L10n.locale = .current }

    let onDevice = PasteImportProgressPresentation(kind: .onDevice)
    let pcc = PasteImportProgressPresentation(kind: .privateCloudCompute)

    #expect(onDevice.title == L10n.string(.pasteImportProgress))
    #expect(onDevice.modelName == L10n.string(.pasteImportModelOnDevice))
    #expect(pcc.modelName == L10n.string(.pasteImportModelPcc))
    #expect(PasteImportProgressPresentation(kind: .unavailable).modelName == nil)
}
