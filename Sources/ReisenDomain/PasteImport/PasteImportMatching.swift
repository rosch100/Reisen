import Foundation

/// Ergebnis des Abgleichs eines Paste-Import-Drafts gegen den Bestand.
public enum PasteImportMatch: Equatable, Sendable {
    case unique(Booking)
    case none
    case ambiguous
}

/// Ordnet einen Paste-Import-Draft genau einer bestehenden Buchung zu.
///
/// Reihenfolge: externe URL, Bestätigungscode, Datums-Fingerprint. Je Stufe gilt:
/// ein Kandidat → `unique`, mehrere → `ambiguous`, keiner → nächste Stufe.
/// Der Fingerprint entfällt bei Platzhalter-`endAt`, weil er dann keinen echten Zeitraum beschreibt.
public enum PasteImportMatching {
    public static func match(
        draft: PasteImportDraft,
        existing: [Booking],
        index: SyncBookingMatchIndex,
        calendar: Calendar,
        normalizer: BookingTimeNormalizer
    ) -> PasteImportMatch {
        if let byURL = byURL(draft.externalUrl, in: existing) {
            return byURL
        }
        if let byCode = byCode(draft.confirmationCode, in: index.byConfirmationCode) {
            return byCode
        }
        if let byFingerprint = byFingerprint(
            draft: draft,
            in: index.byDateFingerprint,
            calendar: calendar,
            normalizer: normalizer
        ) {
            return byFingerprint
        }
        return .none
    }

    /// URL-Treffer werden über den Bestand gezählt; `SyncBookingMatchIndex.byURL` überschreibt Kollisionen.
    private static func byURL(_ url: String?, in existing: [Booking]) -> PasteImportMatch? {
        guard let url else { return nil }
        return resolve(existing.filter { $0.externalUrl == url })
    }

    private static func byCode(
        _ code: String?,
        in byConfirmationCode: [String: [UUID: Booking]]
    ) -> PasteImportMatch? {
        guard let code else { return nil }
        return resolve(byConfirmationCode[code]?.values)
    }

    private static func byFingerprint(
        draft: PasteImportDraft,
        in byDateFingerprint: [SyncBookingDateFingerprintKey: [UUID: Booking]],
        calendar: Calendar,
        normalizer: BookingTimeNormalizer
    ) -> PasteImportMatch? {
        guard !draft.endAtIsPlaceholder else { return nil }
        let key = SyncBookingDateFingerprint.key(
            for: draft.asProviderDraft(),
            calendar: calendar,
            normalizer: normalizer
        )
        return resolve(byDateFingerprint[key]?.values)
    }

    private static func resolve<Candidates: Collection>(
        _ candidates: Candidates?
    ) -> PasteImportMatch? where Candidates.Element == Booking {
        guard let candidates, let first = candidates.first else { return nil }
        return candidates.count == 1 ? .unique(first) : .ambiguous
    }
}
