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
    @Environment(\.providerNativeAppPresence) private var nativeAppPresence
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
                    Section(L10n.string(.tripOverview)) {
                        Text(trip.title)
                        Text("\(L10n.string(.tripPeriod)): \(L10n.format(.tripPeriodRange, trip.startDate.formatted(date: .abbreviated, time: .omitted), trip.endDate.formatted(date: .abbreviated, time: .omitted)))")
                            .foregroundStyle(.secondary)
                        if let destination = trip.destination, !destination.isEmpty {
                            Text(destination)
                        }
                        if trip.resolvedBookings.isEmpty {
                            Button(L10n.string(.actionAssignBookings)) {
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
                        .contextMenu {
                            if let url = booking.browserURL {
                                BookingPortalOpenButton(
                                    bookingURL: url,
                                    providerID: booking.provider,
                                    isNativeAppInstalled: nativeAppPresence.isInstalled(booking.provider)
                                )
                            }
                        }
                    }
                }
                .navigationTitle(trip.title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(L10n.string(.commonEdit)) { tripToEdit = trip }
                            Button(L10n.string(.actionAssignBookings)) { showAssignBookings = true }
                            Divider()
                            Button(L10n.string(.actionDeleteTrip), role: .destructive) {
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
                    L10n.string(.actionDeleteTripConfirm),
                    isPresented: $showDeleteConfirm,
                    titleVisibility: .visible
                ) {
                    Button(L10n.string(.commonDelete), role: .destructive) {
                        deleteTrip(trip)
                    }
                    Button(L10n.string(.commonCancel), role: .cancel) {}
                } message: {
                    Text(TripDeletion.confirmationMessage)
                }
            } else {
                ContentUnavailableView(L10n.string(.tripTripMissing), systemImage: "magnifyingglass")
            }
        }
    }

    private func deleteTrip(_ trip: SDTrip) {
        try? TripDeletion.perform(trip: trip, in: modelContext)
        dismiss()
    }
}
