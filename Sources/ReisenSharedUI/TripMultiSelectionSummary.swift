import SwiftUI
import ReisenDomain

public struct TripMultiSelectionSummary: View {
    let selectedCount: Int
    var onDelete: (() -> Void)?

    public init(selectedCount: Int, onDelete: (() -> Void)? = nil) {
        self.selectedCount = selectedCount
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.format(.tripSelectedTrips, selectedCount))
                .font(.headline)

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Text(L10n.string(.actionDeleteTrip))
                }
                .controlSize(.large)
                .accessibilityIdentifier(UITestingIdentifiers.deleteTripMenu)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .accessibilityIdentifier(UITestingIdentifiers.tripMultiSelectionSummary)
    }
}
