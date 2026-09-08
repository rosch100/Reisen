import SwiftUI
import SwiftData

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenDiagnostics

struct TripDetailIOS: View {
    let tripID: UUID
    @Binding var focusBookingID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.providerNativeAppPresence) private var nativeAppPresence
    @Environment(\.providerSessionHub) private var sessionHub
    @Environment(\.openURL) private var openURL
    @Query private var trips: [SDTrip]
    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]

    @State private var tripToEdit: SDTrip?
    @State private var showAssignBookings = false
    @State private var showDeleteConfirm = false
    @State private var persistErrorMessage: String?
    @State private var pendingDeleteBooking: SDBooking?
    @State private var showBookingDeleteConfirm = false
    @State private var pendingRemoveBooking: SDBooking?
    @State private var showRemoveFromTripConfirmation = false
    @State private var presentedBookingID: PresentedBookingID?
    @State private var cancelRequest: BookingPortalCancelRequest?

    init(tripID: UUID, focusBookingID: Binding<UUID?> = .constant(nil)) {
        self.tripID = tripID
        self._focusBookingID = focusBookingID
    }

    private struct PresentedBookingID: Identifiable, Hashable {
        let id: UUID
    }

    var trip: SDTrip? {
        trips.first(where: { $0.id == tripID })
    }

    private func assignCandidates(for trip: SDTrip) -> [SDBooking] {
        allBookings.filter { OpenBookingMatching.isCandidate($0, for: trip) }
    }

    private var overlapPartnerIDsByBookingID: [UUID: [UUID]] {
        BookingDayOverlap.partnerIDsByID(sdBookings: allBookings)
    }

    private var bookingPresentationTitleByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: allBookings.map { ($0.id, $0.presentationTitle) })
    }

    private func overlapPartnerTitles(for bookingID: UUID) -> [String] {
        BookingOverlapCaption.partnerTitles(
            for: bookingID,
            partnerIDsByBookingID: overlapPartnerIDsByBookingID,
            titleByID: bookingPresentationTitleByID
        )
    }

    var body: some View {
        Group {
            if let trip {
                List {
                    Section(L10n.string(.tripOverview)) {
                        let destination = trip.destination.flatMap { $0.isEmpty ? nil : $0 }
                        let notes = trip.notes.flatMap { $0.isEmpty ? nil : $0 }
                        let completeness = trip.completeness()
                        let fields = TripOverviewPresentation.visibleFields(
                            hasDestination: destination != nil,
                            hasBookings: completeness.hasBookings,
                            hasNotes: notes != nil
                        )
                        ForEach(fields, id: \.self) { field in
                            switch field {
                            case .title:
                                CopyableLabeledValue(
                                    label: L10n.string(.editorTitle),
                                    value: trip.title,
                                    kind: .standard,
                                    style: .list,
                                    valueTextStyle: .headline
                                )
                            case .destination:
                                if let destination {
                                    CopyableLabeledValue(
                                        label: L10n.string(.tripDestination),
                                        value: destination,
                                        kind: .standard,
                                        style: .list
                                    )
                                }
                            case .period:
                                CopyableLabeledValue(
                                    label: L10n.string(.tripPeriod),
                                    value: TripDateBounds.formattedAbbreviatedRange(
                                        start: trip.startDate,
                                        end: trip.endDate
                                    ),
                                    kind: .standard,
                                    style: .list
                                )
                            case .cost:
                                TripCostOverviewIOSRows(trip: trip)
                            case .completeness:
                                TripCompletenessOverviewRow(completeness: completeness)
                            case .notes:
                                if let notes {
                                    CopyableLabeledValue(
                                        label: L10n.string(.tripNotes),
                                        value: notes,
                                        kind: .standard,
                                        style: .list
                                    )
                                }
                            }
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
                        Button {
                            presentBookingDetail(bookingID: booking.id)
                        } label: {
                            HStack {
                                OpenBookingRow(
                                    booking: booking,
                                    partnerTitles: overlapPartnerTitles(for: booking.id)
                                )
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(UITestingIdentifiers.bookingRow(booking.id))
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
                            BookingPortalCancelMenuItems(
                                booking: booking,
                                hasSessionWebView: sessionHub.hasSessionWebView(for: booking),
                                onPresentCancel: { presentation, url in
                                    BookingPortalCancelRequest.route(
                                        presentation,
                                        url: url,
                                        booking: booking,
                                        openURL: { openURL($0) },
                                        setCancelRequest: { cancelRequest = $0 }
                                    )
                                }
                            )
                            Button(L10n.string(.actionRemoveFromTrip), role: .destructive) {
                                requestRemoveFromTrip(booking)
                            }
                            Button(L10n.string(.actionDeleteEllipsis), role: .destructive) {
                                requestDeleteBooking(booking)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            ForEach(
                                BookingRowSwipeActions.actions(for: .tripAssignedBooking, edge: .trailing),
                                id: \.self
                            ) { action in
                                tripBookingSwipeButton(action, booking: booking)
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            ForEach(
                                BookingRowSwipeActions.actions(for: .tripAssignedBooking, edge: .leading),
                                id: \.self
                            ) { action in
                                tripBookingSwipeButton(action, booking: booking)
                            }
                        }
                    }
                }
                .navigationTitle(trip.title)
                .id(trip.id)
                .navigationDestination(item: $presentedBookingID) { token in
                    BookingDetailIOS(bookingID: token.id)
                }
                .onAppear {
                    applyFocusBookingIfNeeded()
                }
                .onChange(of: focusBookingID) { _, _ in
                    applyFocusBookingIfNeeded()
                }
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
                .bookingTripConfirmDialogs(
                    showDeleteConfirmation: $showBookingDeleteConfirm,
                    showRemoveFromTripConfirmation: $showRemoveFromTripConfirmation,
                    bookingTitle: (pendingDeleteBooking ?? pendingRemoveBooking)?.presentationTitle
                        ?? L10n.string(.editorBooking),
                    showsSyncRestoreWarning: pendingDeleteBooking.map { $0.provider != .manual } ?? false,
                    onConfirmDelete: deletePendingBooking,
                    onConfirmRemove: removePendingBookingFromTrip,
                    onCancelDelete: { pendingDeleteBooking = nil },
                    onCancelRemove: { pendingRemoveBooking = nil }
                )
                .persistFailureAlert(message: $persistErrorMessage)
                .bookingPortalCancelSheet($cancelRequest)
            } else {
                ContentUnavailableView(L10n.string(.tripTripMissing), systemImage: "magnifyingglass")
            }
        }
    }

    @ViewBuilder
    private func tripBookingSwipeButton(
        _ action: BookingRowSwipeAction,
        booking: SDBooking
    ) -> some View {
        switch action {
        case .delete:
            Button(L10n.string(.commonDelete), role: .destructive) {
                requestDeleteBooking(booking)
            }
            .accessibilityIdentifier(UITestingIdentifiers.swipeBookingDelete)
        case .removeFromTrip:
            Button(L10n.string(.commonRemove)) {
                requestRemoveFromTrip(booking)
            }
            .tint(.orange)
            .accessibilityIdentifier(UITestingIdentifiers.swipeBookingRemoveFromTrip)
        case .createTripFromBooking:
            EmptyView()
        }
    }

    private func requestDeleteBooking(_ booking: SDBooking) {
        pendingDeleteBooking = booking
        showBookingDeleteConfirm = true
    }

    private func requestRemoveFromTrip(_ booking: SDBooking) {
        pendingRemoveBooking = booking
        showRemoveFromTripConfirmation = true
    }

    private func applyFocusBookingIfNeeded() {
        guard let bookingID = focusBookingID else { return }
        presentBookingDetail(bookingID: bookingID)
        focusBookingID = nil
    }

    private func presentBookingDetail(bookingID: UUID) {
        var presentedID = presentedBookingID?.id
        TripBookingDetailNavigation.applyUserSelect(
            bookingID: bookingID,
            presentedBookingID: &presentedID
        )
        presentedBookingID = presentedID.map(PresentedBookingID.init(id:))
        Self.recordBookingDetailSelect()
    }

    private static func recordBookingDetailSelect() {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .manual,
                        operation: "trip_booking_detail_select"
                    ),
                    component: "TripDetailIOS",
                    phase: "navigation",
                    event: "booking_detail_select",
                    result: .succeeded,
                    reason: "item_destination_via_presented_binding",
                    visibility: .localDebugOnly
                )
            )
        }
    }

    private func deletePendingBooking() {
        guard let booking = pendingDeleteBooking else { return }
        do {
            try BookingDeletion.perform(booking: booking, in: modelContext)
            pendingDeleteBooking = nil
        } catch {
            persistErrorMessage = error.localizedDescription
            Self.recordPersistFailure(operation: "booking_delete", error: error)
        }
    }

    private func removePendingBookingFromTrip() {
        guard let booking = pendingRemoveBooking else { return }
        Self.recordRemoveFromTrip(result: .started)
        booking.trip = nil
        do {
            try modelContext.save()
            pendingRemoveBooking = nil
            Self.recordRemoveFromTrip(result: .succeeded)
        } catch {
            persistErrorMessage = error.localizedDescription
            Self.recordPersistFailure(operation: "booking_remove_from_trip", error: error)
            pendingRemoveBooking = nil
        }
    }

    private func deleteTrip(_ trip: SDTrip, bookings policy: TripDeletionBookingPolicy) {
        do {
            try TripDeletion.perform(trip: trip, in: modelContext, bookings: policy)
            dismiss()
        } catch {
            persistErrorMessage = error.localizedDescription
            Self.recordPersistFailure(operation: "trip_delete", error: error)
        }
    }

    private static func recordRemoveFromTrip(result: DiagnosticResult) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .manual,
                        operation: "booking_remove_from_trip"
                    ),
                    component: "TripDetailIOS",
                    phase: "persist",
                    event: "booking_remove_from_trip",
                    result: result,
                    reason: result == .started ? "confirm_accepted" : "save_ok",
                    visibility: .localDebugOnly
                )
            )
        }
    }

    private static func recordPersistFailure(operation: String, error: Error) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .manual,
                        operation: operation
                    ),
                    component: "TripDetailIOS",
                    phase: "persist",
                    event: operation,
                    result: .failed,
                    reason: String(describing: type(of: error)),
                    visibility: .publicDiagnostic
                )
            )
        }
    }
}
