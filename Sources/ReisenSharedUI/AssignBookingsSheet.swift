import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData

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
                    List(candidates, id: \.id) { booking in
                        Button {
                            toggleSelection(for: booking.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(booking.displayTitle)
                                        .font(.headline)
                                    Text("\(booking.startAt.formatted(date: .abbreviated, time: .shortened)) – \(booking.endAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedBookingIDs.contains(booking.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedBookingIDs.contains(booking.id) ? Color.accentColor : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
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
    }

    private func toggleSelection(for id: UUID) {
        if selectedBookingIDs.contains(id) {
            selectedBookingIDs.remove(id)
        } else {
            selectedBookingIDs.insert(id)
        }
    }

    private func assignSelectedBookings() {
        errorMessage = nil
        do {
            for booking in candidates where selectedBookingIDs.contains(booking.id) {
                booking.trip = trip
            }
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
