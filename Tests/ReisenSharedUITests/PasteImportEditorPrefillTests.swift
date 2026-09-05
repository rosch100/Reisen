import Foundation
import Testing
import ReisenData
import ReisenDomain
import ReisenSharedUI

private let prefillStart = Date(timeIntervalSince1970: 1_800_000_000)
private let prefillEnd = prefillStart.addingTimeInterval(86_400)

private func hotelDraft(
    title: String?,
    confirmationCode: String?,
    status: BookingStatus = .unknown
) -> PasteImportDraft {
    PasteImportDraft(
        bookingType: .hotel,
        startAt: prefillStart,
        endAt: prefillEnd,
        endAtIsPlaceholder: false,
        title: title,
        confirmationCode: confirmationCode,
        locationTo: "Lissabon",
        status: status
    )
}

@Test func pasteImportEditorPrefill_neu_takesCandidateValuesWithoutEditorDefaults() {
    let candidate = PasteImportCandidate(
        draft: hotelDraft(title: "Hotel Lissabon", confirmationCode: "ABC123"),
        match: .none
    )
    #expect(candidate.isErgaenzen == false)

    let draft = PasteImportEditorPrefill.draft(
        for: candidate,
        existing: nil
    )

    #expect(draft.bookingID == nil)
    #expect(draft.provider == .manual)
    #expect(draft.bookingType == .hotel)
    #expect(draft.status == .unknown)
    #expect(draft.title == "Hotel Lissabon")
    #expect(draft.confirmationCode == "ABC123")
    #expect(draft.locationTo == "Lissabon")
    #expect(draft.startAt == HotelStayDate.localPickerDate(fromStored: prefillStart))
    #expect(draft.endAt == HotelStayDate.localPickerDate(fromStored: prefillEnd))
    #expect(draft.hotelCheckInMinutesText.isEmpty)
    #expect(draft.hotelCheckOutMinutesText.isEmpty)
}

@Test func pasteImportEditorPrefill_ambiguous_staysNew() {
    let candidate = PasteImportCandidate(
        draft: hotelDraft(title: "Hotel Lissabon", confirmationCode: nil),
        match: .ambiguous
    )
    #expect(candidate.isErgaenzen == false)

    let draft = PasteImportEditorPrefill.draft(
        for: candidate,
        existing: nil
    )

    #expect(draft.bookingID == nil)
    #expect(draft.provider == .manual)
    #expect(draft.confirmationCode.isEmpty)
}

@Test func pasteImportEditorPrefill_neu_keepsExtractedHotelMinutes() {
    var pasteDraft = hotelDraft(title: "Hotel Lissabon", confirmationCode: nil)
    pasteDraft.hotelCheckInMinutes = 900
    pasteDraft.hotelCheckOutMinutes = 660
    let candidate = PasteImportCandidate(draft: pasteDraft, match: .none)

    let draft = PasteImportEditorPrefill.draft(
        for: candidate,
        existing: nil
    )

    #expect(draft.hotelCheckInMinutesText == "900")
    #expect(draft.hotelCheckOutMinutesText == "660")
}

@MainActor
@Test func pasteImportEditorPrefill_ergaenzen_fillsGapsAndKeepsExistingProvider() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext

    let existing = SDBooking(
        providerRaw: ProviderID.check24.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Hotel Lissabon",
        confirmationCode: "",
        startAt: prefillStart,
        endAt: prefillEnd,
        locationTo: "Lissabon",
        statusRaw: BookingStatus.confirmed.rawValue
    )
    context.insert(existing)

    let candidate = PasteImportCandidate(
        draft: hotelDraft(title: "Anderer Titel", confirmationCode: "XYZ"),
        match: .unique(DomainMapper.booking(from: existing))
    )
    #expect(candidate.isErgaenzen)

    let draft = PasteImportEditorPrefill.draft(
        for: candidate,
        existing: existing
    )

    #expect(draft.bookingID == existing.id)
    #expect(draft.provider == .check24)
    #expect(draft.confirmationCode == "XYZ")
    #expect(draft.title == "Hotel Lissabon")
    #expect(draft.status == .confirmed)
    #expect(existing.confirmationCode == "")
    #expect(existing.title == "Hotel Lissabon")
}

@MainActor
@Test func pasteImportEditorPrefill_ergaenzen_matchesEditorMappingOfUnchangedBooking() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext

    let existing = SDBooking(
        providerRaw: ProviderID.check24.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Hotel Lissabon",
        confirmationCode: "ABC123",
        startAt: prefillStart,
        endAt: prefillEnd,
        locationTo: "Lissabon",
        statusRaw: BookingStatus.confirmed.rawValue
    )
    context.insert(existing)

    let candidate = PasteImportCandidate(
        draft: hotelDraft(title: "Anderer Titel", confirmationCode: "XYZ"),
        match: .unique(DomainMapper.booking(from: existing))
    )

    let draft = PasteImportEditorPrefill.draft(
        for: candidate,
        existing: existing
    )

    #expect(draft == BookingEditorDraft.fromExisting(existing))
}
