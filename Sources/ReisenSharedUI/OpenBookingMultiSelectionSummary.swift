import SwiftUI
import ReisenDomain
import ReisenData

/// Summary for multiple selected open bookings (macOS detail / iOS edit toolbar).
public struct OpenBookingMultiSelectionSummary: View {
    let selected: [SDBooking]
    var onCreateTrip: () -> Void

    public init(
        selected: [SDBooking],
        onCreateTrip: @escaping () -> Void
    ) {
        self.selected = selected
        self.onCreateTrip = onCreateTrip
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateRangeText: String? {
        OpenBookingCreateTripAction.dateRangeText(for: selected)
    }
}
