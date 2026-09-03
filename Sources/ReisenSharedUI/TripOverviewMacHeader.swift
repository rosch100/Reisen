import SwiftUI
import ReisenDomain

/// macOS Trip-Übersicht: Hierarchie Titel → Kontext → Meta → Kosten → Completeness → Notes.
public struct TripOverviewMacHeader: View {
    public let title: String
    public let destination: String?
    public let periodText: String
    public let costPrimary: String
    public let costSecondary: String?
    public let completeness: TripCompleteness
    public let notes: String?

    public init(
        title: String,
        destination: String?,
        periodText: String,
        costPrimary: String,
        costSecondary: String?,
        completeness: TripCompleteness,
        notes: String?
    ) {
        self.title = title
        self.destination = destination
        self.periodText = periodText
        self.costPrimary = costPrimary
        self.costSecondary = costSecondary
        self.completeness = completeness
        self.notes = notes
    }

    public var body: some View {
        let fields = TripOverviewPresentation.visibleFields(
            hasDestination: destination.map { !$0.isEmpty } ?? false,
            hasBookings: completeness.hasBookings,
            hasNotes: notes.map { !$0.isEmpty } ?? false
        )
        VStack(alignment: .leading, spacing: 8) {
            // Explizites StaticText-AX (VStack/Color.clear oft ohne Identifier in macOS-XCUI).
            Text(L10n.string(.tripOverview))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .accessibilityIdentifier(UITestingIdentifiers.tripOverview)
            ForEach(fields, id: \.self) { field in
                fieldView(field)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func fieldView(_ field: TripOverviewField) -> some View {
        switch field {
        case .title:
            Text(title)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(UITestingIdentifiers.tripOverviewTitle)
        case .destination:
            if let destination {
                Text(destination)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        case .period:
            overviewFact(label: L10n.string(.tripPeriod), value: periodText)
        case .cost:
            VStack(alignment: .leading, spacing: 2) {
                overviewFact(label: L10n.string(.bookingDetailPrice), value: costPrimary)
                if let costSecondary {
                    Text(costSecondary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .help(costSecondary)
                }
            }
            .accessibilityElement(children: .combine)
        case .completeness:
            overviewFact(
                label: L10n.string(.tripCompletenessLabel),
                value: L10n.tripCompletenessOverviewFactValue(completeness)
            )
            .help(L10n.string(.tripCompletenessHelp))
            TripCompletenessMacDetailCaption(completeness: completeness)
        case .notes:
            if let notes {
                CopyableFieldValue(
                    value: notes,
                    kind: .standard,
                    textStyle: .callout,
                    foregroundStyle: .secondary,
                    lineLimit: 4
                )
                .accessibilityLabel(L10n.string(.tripNotes))
            }
        }
    }

    private func overviewFact(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            CopyableFieldValue(
                value: value,
                kind: .standard,
                textStyle: .body,
                lineLimit: 1
            )
        }
    }
}
