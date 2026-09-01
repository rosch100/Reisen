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
