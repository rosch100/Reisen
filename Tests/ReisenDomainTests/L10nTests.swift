import Foundation
import Testing
import ReisenDomain

@Test func l10n_allKeysResolveInGerman() {
    L10n.locale = Locale(identifier: "de")
    defer { L10n.locale = .current }

    for key in L10nKey.allCases {
        let value = L10n.string(key)
        #expect(!value.isEmpty, "Key \(key.rawValue) liefert leeren String")
        #expect(value != key.rawValue, "Key \(key.rawValue) wurde nicht übersetzt")
    }
}

@Test func l10n_allKeysResolveInEnglish() {
    L10n.locale = Locale(identifier: "en")
    defer { L10n.locale = .current }

    for key in L10nKey.allCases {
        let value = L10n.string(key)
        #expect(!value.isEmpty, "Key \(key.rawValue) liefert leeren String in EN")
        #expect(value != key.rawValue, "Key \(key.rawValue) wurde nicht übersetzt in EN")
    }
}

@Test func l10n_overlapLabel_withAndWithoutCount() {
    L10n.locale = Locale(identifier: "de")
    defer { L10n.locale = .current }

    #expect(L10n.overlapLabel(extraCount: 0) == L10n.string(.bookingOverlap))
    #expect(L10n.overlapLabel(extraCount: 2) == L10n.format(.bookingOverlapWithCount, 2))
}
