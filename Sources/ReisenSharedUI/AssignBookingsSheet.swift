import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData
import ReisenDiagnostics

public struct AssignBookingsSheet: View {
    let trip: SDTrip
    let candidates: [SDBooking]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedBookingIDs: Set<UUID>
    @State private var errorMessage: String?

    public init(
        trip: SDTrip,
        candidates: [SDBooking],
        initiallySelectedBookingIDs: Set<UUID> = []
    ) {
        self.trip = trip
        self.candidates = candidates
        let candidateIDs = Set(candidates.map(\.id))
        _selectedBookingIDs = State(initialValue: initiallySelectedBookingIDs.intersection(candidateIDs))
    }

    public var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    ContentUnavailableView(
                        L10n.string(.tripNoOpenInRange),
                        systemImage: "tray",
                        description: Text(L10n.string(.assignNoOpenInRange))
                    )
                } else {
                    // List(selection:) statt Button-Toggle: macOS-XCUI trifft Selection zuverlässig.
                    List(candidates, id: \.id, selection: $selectedBookingIDs) { booking in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(booking.presentationTitle)
                                    .font(.headline)
                                Text(BookingScheduleRangeText.make(for: booking))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: selectedBookingIDs.contains(booking.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedBookingIDs.contains(booking.id) ? Color.accentColor : .secondary)
                                .accessibilityHidden(true)
                        }
                        .tag(booking.id)
                        .accessibilityIdentifier(UITestingIdentifiers.assignBookingsCandidate(booking.id))
                    }
#if os(iOS)
                    .environment(\.editMode, .constant(.active))
#endif
                }
            }
            .navigationTitle(L10n.string(.assignTitle))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.commonCancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string(.commonAssign)) { assignSelectedBookings() }
                        .accessibilityIdentifier(UITestingIdentifiers.assignBookingsConfirm)
                        .disabled(selectedBookingIDs.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.bar)
                }
            }
#if os(iOS)
            .reisenSheetDetents()
#endif
        }
#if os(macOS)
        .frame(width: 520, height: 420)
#endif
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(UITestingIdentifiers.assignBookingsSheet)
        .accessibilityLabel(L10n.string(.assignTitle))
    }

    private func assignSelectedBookings() {
        errorMessage = nil
        do {
            var affectedTripIDs = Set<UUID>()
            affectedTripIDs.insert(trip.id)
            for booking in candidates where selectedBookingIDs.contains(booking.id) {
                if let oldID = booking.trip?.id {
                    affectedTripIDs.insert(oldID)
                }
                booking.trip = trip
            }
            try modelContext.save()
            try AutoGapReconcileTrigger.run(tripIDs: affectedTripIDs, in: modelContext)
            try modelContext.save()
            dismiss()
        } catch {
            SharedUIPersistDiagnostics.recordFailure(
                component: "AssignBookingsSheet",
                operation: "assign_bookings_save",
                error: error
            )
            errorMessage = error.localizedDescription
        }
    }
}
