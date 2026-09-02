import SwiftUI
import ReisenDomain
import ReisenData

/// Summary for multiple selected open bookings (macOS detail / iOS edit toolbar).
public struct OpenBookingMultiSelectionSummary: View {
    let selected: [SDBooking]
    var onCreateTrip: () -> Void
    var onDelete: (() -> Void)?

    public init(
        selected: [SDBooking],
        onCreateTrip: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.selected = selected
        self.onCreateTrip = onCreateTrip
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.format(.tripSelectedOpenBookings, selected.count))
                    .font(.headline)
                if let dateRangeText {
                    Text(dateRangeText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            #if os(macOS)
            Button(action: onCreateTrip) {
                CreateTripFromBookingsLabel()
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            #else
            Button(action: onCreateTrip) {
                CreateTripFromBookingsLabel()
            }
            .buttonStyle(.borderedProminent)
            #endif

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Text(L10n.string(.actionDeleteEllipsis))
                }
                .controlSize(.large)
                .accessibilityIdentifier(UITestingIdentifiers.deleteBookingMenu)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(UITestingIdentifiers.openBookingMultiSelectionSummary)
    }

    private var dateRangeText: String? {
        OpenBookingCreateTripAction.dateRangeText(for: selected)
    }
}
