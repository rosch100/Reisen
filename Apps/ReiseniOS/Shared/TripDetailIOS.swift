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
    @State private var persistErrorMessage: String?
    @State private var pendingDeleteBooking: SDBooking?
    @State private var showBookingDeleteConfirm = false

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
                        CopyableLabeledValue(
                            label: L10n.string(.editorTitle),
                            value: trip.title,
                            kind: .standard,
                            style: .list,
                            valueTextStyle: .headline
                        )
                        CopyableLabeledValue(
                            label: L10n.string(.tripPeriod),
                            value: L10n.format(
                                .tripPeriodRange,
                                trip.startDate.formatted(date: .abbreviated, time: .omitted),
                                trip.endDate.formatted(date: .abbreviated, time: .omitted)
                            ),
                            kind: .standard,
                            style: .list
                        )
                        if let destination = trip.destination, !destination.isEmpty {
                            CopyableLabeledValue(
                                label: L10n.string(.tripDestination),
                                value: destination,
                                kind: .standard,
                                style: .list
                            )
                        }
                        TripCompletenessOverviewRow(completeness: trip.completeness())
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
                            BookingCopyConfirmationMenuItems(booking: booking)
                            if let url = booking.browserURL {
                                BookingPortalOpenButton(
                                    bookingURL: url,
                                    providerID: booking.provider,
                                    isNativeAppInstalled: nativeAppPresence.isInstalled(booking.provider)
                                )
                                CopyLinkMenuItem(url: url)
                            }
                            Button(L10n.string(.actionDeleteEllipsis), role: .destructive) {
                                pendingDeleteBooking = booking
                                showBookingDeleteConfirm = true
                            }
                        }
                    }
                }
                .navigationTitle(trip.title)
                .id(trip.id)
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
                .tripDeleteConfirmDialog(
                    isPresented: $showDeleteConfirm,
                    tripTitle: trip.title,
                    bookingCount: trip.resolvedBookings.count,
                    onKeepBookings: { deleteTrip(trip, bookings: .keepAsOpen) },
                    onDeleteBookings: { deleteTrip(trip, bookings: .deleteContained) }
                )
                .bookingDeleteConfirmAlert(
                    isPresented: $showBookingDeleteConfirm,
                    bookingTitle: pendingDeleteBooking?.presentationTitle ?? L10n.string(.editorBooking),
                    showsSyncRestoreWarning: pendingDeleteBooking.map { $0.provider != .manual } ?? false,
                    onConfirm: deletePendingBooking,
                    onCancel: { pendingDeleteBooking = nil }
                )
                .alert(L10n.string(.tripAssignFailed), isPresented: Binding(
                    get: { persistErrorMessage != nil },
                    set: { if !$0 { persistErrorMessage = nil } }
                )) {
                    Button(L10n.string(.commonOk), role: .cancel) { persistErrorMessage = nil }
                } message: {
                    if let persistErrorMessage {
                        Text(persistErrorMessage)
                    }
                }
            } else {
                ContentUnavailableView(L10n.string(.tripTripMissing), systemImage: "magnifyingglass")
            }
        }
    }

    private func deletePendingBooking() {
        guard let booking = pendingDeleteBooking else { return }
        do {
            try BookingDeletion.perform(booking: booking, in: modelContext)
            pendingDeleteBooking = nil
        } catch {
            persistErrorMessage = error.localizedDescription
        }
    }

    private func deleteTrip(_ trip: SDTrip, bookings policy: TripDeletionBookingPolicy) {
        do {
            try TripDeletion.perform(trip: trip, in: modelContext, bookings: policy)
            dismiss()
        } catch {
            persistErrorMessage = error.localizedDescription
        }
    }
}
