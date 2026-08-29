import SwiftUI
import ReisenDomain

/// Anzeigewerte einer Kandidatenzeile: Neu/Ergänzen als **Text**, nicht nur als Farbe.
public struct PasteImportCandidatePresentation: Equatable, Sendable {
    public let title: String
    public let bookingType: BookingType
    public let badgeText: String
    public let ambiguousHint: String?

    /// Screenreader lesen dieselbe Einordnung wie sehende Nutzer.
    public var accessibilityLabel: String { badgeText }

    public init(candidate: PasteImportCandidate) {
        title = candidate.draft.title ?? candidate.draft.bookingType.defaultDisplayTitle
        bookingType = candidate.draft.bookingType
        badgeText = L10n.string(candidate.isErgaenzen ? .pasteImportBadgeEnrich : .pasteImportBadgeNew)
        ambiguousHint = candidate.showsAmbiguousHint ? L10n.string(.pasteImportAmbiguousHint) : nil
    }
}

/// Übersicht der erkannten Buchungen vor dem Editor-Durchlauf.
public struct PasteImportCandidateList: View {
    private let candidates: [PasteImportCandidate]
    private let sourceWasTruncated: Bool

    public init(candidates: [PasteImportCandidate], sourceWasTruncated: Bool = false) {
        self.candidates = candidates
        self.sourceWasTruncated = sourceWasTruncated
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string(.pasteImportCandidatesTitle))
                .font(.headline)

            if sourceWasTruncated {
                Label(
                    L10n.string(.pasteImportSourceTruncated),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if candidates.isEmpty {
                Text(L10n.string(.pasteImportEmpty))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(candidates.enumerated()), id: \.offset) { _, candidate in
                    PasteImportCandidateRow(
                        presentation: PasteImportCandidatePresentation(candidate: candidate)
                    )
                }
            }
        }
    }
}

private struct PasteImportCandidateRow: View {
    let presentation: PasteImportCandidatePresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(presentation.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(presentation.badgeText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                    .accessibilityLabel(Text(presentation.accessibilityLabel))
            }

            BookingTypeLabel(presentation.bookingType)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let ambiguousHint = presentation.ambiguousHint {
                Label(ambiguousHint, systemImage: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
