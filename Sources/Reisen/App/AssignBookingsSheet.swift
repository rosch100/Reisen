import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData

struct AssignBookingsSheet: View {
    let trip: SDTrip
    let candidates: [SDBooking]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedBookingIDs: Set<UUID> = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Text("Buchungen zuordnen")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            if let errorMessage {
                CopyableTextView(
                    text: errorMessage,
                    font: .preferredFont(forTextStyle: .callout),
                    textColor: .systemRed
                )
                .padding(.horizontal, 16)
            }

            List(candidates, id: \.id) { booking in
                Button {
                    toggleSelection(for: booking.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(booking.title ?? booking.bookingType.rawValue.capitalized)
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
            .frame(maxHeight: .infinity)

            Divider()

            HStack {
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Zuordnen") { assignSelectedBookings() }
                    .disabled(selectedBookingIDs.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 520, height: 420)
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
