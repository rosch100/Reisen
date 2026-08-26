import SwiftUI
import SwiftData

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData

struct TripDetailIOS: View {
    let tripID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var trips: [SDTrip]
    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]

    @State private var tripToEdit: SDTrip?
    @State private var showAssignBookings = false
    @State private var showDeleteConfirm = false

    var trip: SDTrip? {
        trips.first(where: { $0.id == tripID })
    }

    private func assignCandidates(for trip: SDTrip) -> [SDBooking] {
        allBookings.filter { OpenBookingMatching.isCandidate($0, for: trip) }
    }

    var body: some View {
        Group {
            if let trip {
                List {
                    Section("Übersicht") {
                        Text(trip.title)
                        Text("Zeitraum: \(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundStyle(.secondary)
                        if let destination = trip.destination, !destination.isEmpty {
                            Text(destination)
                        }
                        if trip.resolvedBookings.isEmpty {
                            Button("Buchungen zuordnen") {
                                showAssignBookings = true
                            }
                        }
                    }

                    TripTimelineSection(
                        trip: trip,
                        bookings: trip.timelineBookings()
                    ) { booking in
                        NavigationLink(destination: BookingDetailIOS(bookingID: booking.id)) {
                            OpenBookingRow(booking: booking)
                        }
                    }
                }
                .navigationTitle(trip.title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Bearbeiten") { tripToEdit = trip }
                            Button("Buchungen zuordnen") { showAssignBookings = true }
                            Divider()
                            Button("Reise löschen", role: .destructive) {
                                showDeleteConfirm = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(item: $tripToEdit) { trip in
                    TripEditorSheet(mode: .edit, trip: trip)
                    .reisenSheetDetents()
                }
                .sheet(isPresented: $showAssignBookings) {
                    AssignBookingsSheet(trip: trip, candidates: assignCandidates(for: trip))
                }
                .confirmationDialog(
                    "Reise löschen?",
                    isPresented: $showDeleteConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Löschen", role: .destructive) {
                        deleteTrip(trip)
                    }
                    Button("Abbrechen", role: .cancel) {}
                } message: {
                    Text(TripDeletion.confirmationMessage)
                }
            } else {
                ContentUnavailableView("Reise nicht gefunden.", systemImage: "magnifyingglass")
            }
        }
    }

    private func deleteTrip(_ trip: SDTrip) {
        try? TripDeletion.perform(trip: trip, in: modelContext)
        dismiss()
    }
}
