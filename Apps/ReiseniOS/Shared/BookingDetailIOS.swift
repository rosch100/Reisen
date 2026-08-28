import SwiftUI
import SwiftData
import WebKit

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData

struct BookingDetailIOS: View {
    let bookingID: UUID
    var onTripCreated: ((UUID) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query private var bookings: [SDBooking]
    @Query private var trips: [SDTrip]

    @State private var assignErrorMessage: String?
    @State private var showAssignError = false
    @State private var tripCreateSeed: TripCreateSeed?
    @State private var showCreateTripFromBookingsFailed = false

    @State private var isEditing = false
    @State private var bookingEditorDraft: BookingEditorDraft?

    @State private var pendingDeleteBookingID: UUID?
    @State private var showDeleteConfirmation = false

    @State private var pendingRemoveFromTripBookingID: UUID?
    @State private var showRemoveFromTripConfirmation = false

    private var booking: SDBooking? {
        bookings.first(where: { $0.id == bookingID })
    }

    private var bookingTrip: SDTrip? {
        guard let booking else { return nil }
        return booking.trip
    }

    private var matchingTrip: SDTrip? {
        guard let booking, booking.trip == nil else { return nil }
        return trips.first { OpenBookingMatching.isCandidate(booking, for: $0) }
    }

    #if REISEN_PROVIDER_SYNC
    @Environment(\.providerNativeAppPresence) private var nativeAppPresence
    #endif

    private var externalURL: URL? {
        booking?.browserURL
    }

    private var hotelTimeZone: TimeZone {
        booking?.resolvedHotelTimeZone ?? TimeZone(secondsFromGMT: 0) ?? .current
    }

    private var draftBinding: Binding<BookingEditorDraft>? {
        guard bookingEditorDraft != nil else { return nil }
        return Binding(
            get: { bookingEditorDraft! },
            set: { bookingEditorDraft = $0 }
        )
    }

    private var bookingNavigationTitle: String {
        booking?.presentationTitle ?? L10n.string(.editorBooking)
    }

    private func deletePendingBooking() {
        guard let bookingID = pendingDeleteBookingID,
              let bookingToDelete = bookings.first(where: { $0.id == bookingID }) else { return }
        modelContext.delete(bookingToDelete)
        try? modelContext.save()
        pendingDeleteBookingID = nil
    }

    private func removePendingBookingFromTrip() {
        guard let bookingID = pendingRemoveFromTripBookingID,
              let bookingToRemove = bookings.first(where: { $0.id == bookingID }) else { return }
        bookingToRemove.trip = nil
        try? modelContext.save()
        pendingRemoveFromTripBookingID = nil
    }

    @ViewBuilder
    private func bookingActionsSection(for booking: SDBooking) -> some View {
        Section {
            Button {
                isEditing = true
                bookingEditorDraft = BookingEditorDraft.fromExisting(booking)
            } label: {
                Label(L10n.string(.commonEdit), systemImage: "pencil")
            }
            .help(L10n.string(.tripEditBookingHelp))

            if booking.provider == .manual {
                Button(role: .destructive) {
                    pendingDeleteBookingID = booking.id
                    showDeleteConfirmation = true
                } label: {
                    Text(L10n.string(.actionDeleteEllipsis))
                }
                .help(L10n.string(.tripDeleteManualHelp))
            }

            if booking.trip != nil {
                Button(role: .destructive) {
                    pendingRemoveFromTripBookingID = booking.id
                    showRemoveFromTripConfirmation = true
                } label: {
                    Text(L10n.string(.actionRemoveFromTrip))
                }
                .help(L10n.string(.tripRemoveFromTripHelp))
            }
        }
    }

    @ViewBuilder
    private func bookingRateSections(for booking: SDBooking) -> some View {
        if let rate = booking.rateDetails {
            Section(BookingDetailLabels.rateSection) {
                BookingRateFieldsView(rate: rate, booking: booking)
            }

            if !rate.resolvedRoomItems.isEmpty {
                Section(BookingDetailLabels.roomItemsSection) {
                    BookingRoomItemsView(rate: rate)
                }
            }
        }
    }

    @ViewBuilder
    private func bookingAssignmentSection(for booking: SDBooking) -> some View {
        Section(L10n.string(.tripAssign)) {
            if let trip = bookingTrip {
                Text(L10n.format(.tripInTrip, trip.title))
                    .foregroundStyle(.secondary)
            } else if let trip = matchingTrip {
                Button(L10n.string(.actionAssignToTrip)) {
                    do {
                        booking.trip = trip
                        try modelContext.save()
                    } catch {
                        assignErrorMessage = error.localizedDescription
                        showAssignError = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .help(L10n.string(.tripAssignOpenBookingHelp))
            } else {
                Button {
                    OpenBookingCreateTripAction.assignSeed(
                        fromIDs: [booking.id],
                        in: [booking],
                        seed: $tripCreateSeed,
                        showFailed: $showCreateTripFromBookingsFailed
                    )
                } label: {
                    CreateTripFromBookingsLabel()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private func bookingLinksSection(for booking: SDBooking) -> some View {
        Section(L10n.string(.bookingDetailLinksSection)) {
            if let externalURL {
                #if REISEN_PROVIDER_SYNC
                let installed = nativeAppPresence.isInstalled(booking.provider)
                #else
                let installed = false
                #endif
                BookingPortalOpenLink(
                    bookingURL: externalURL,
                    providerID: booking.provider,
                    isNativeAppInstalled: installed
                )
            } else {
                Text(L10n.string(.bookingDetailNoBrowserLink))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func bookingOverviewSection(for booking: SDBooking) -> some View {
        Section(L10n.string(.tripOverview)) {
            VStack(alignment: .leading, spacing: 6) {
                Text(booking.presentationTitle)
                    .font(.headline)
                    .textSelection(.enabled)

                HStack(spacing: 6) {
                    BookingTypeLabel(booking.bookingType, font: .subheadline)
                    Text("•")
                    Text(booking.provider.rawValue.capitalized)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Text(BookingDetailLabels.dateRange)
                    Text(BookingScheduleRangeText.make(for: booking))
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func bookingTypeDetailsSection(for booking: SDBooking) -> some View {
        Section(booking.bookingType.displayLabel) {
            BookingScheduleFieldsView(booking: booking)
        }
    }

    @ViewBuilder
    private func bookingSyncStatusSection(for booking: SDBooking) -> some View {
        Section(L10n.string(.bookingDetailSyncStatusSection)) {
            if let synced = booking.lastSyncedAt {
                let syncedText = synced.formatted(date: .abbreviated, time: .shortened)
                LabeledContent(L10n.string(.tripLastSynced), value: syncedText)
            } else {
                Text(L10n.string(.tripNotSyncedYet))
                    .foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        Group {
            if let booking {
                List {
                    bookingOverviewSection(for: booking)

                    bookingAssignmentSection(for: booking)

                    bookingTypeDetailsSection(for: booking)

                    bookingRateSections(for: booking)

                    if !booking.resolvedCancellationDeadlines.isEmpty {
                        Section(BookingDetailLabels.cancellationSection) {
                            BookingCancellationDeadlinesView(
                                booking: booking,
                                hotelTimeZone: hotelTimeZone
                            )
                        }
                    }

                    if !booking.resolvedGuestHints.isEmpty {
                        Section(GuestHintCategory.preTravelImportant.displayTitle) {
                            BookingGuestHintsView(booking: booking)
                        }
                    }

                    bookingLinksSection(for: booking)

                    bookingSyncStatusSection(for: booking)

                    bookingActionsSection(for: booking)
                }
            } else {
                ContentUnavailableView(
                    L10n.string(.tripBookingMissing),
                    systemImage: "exclamationmark.triangle",
                    description: Text(L10n.string(.tripBookingUnavailable))
                )
            }
        }
        .navigationTitle(bookingNavigationTitle)
        .alert(L10n.string(.tripAssignFailed), isPresented: $showAssignError) {
            Button(L10n.string(.commonOk), role: .cancel) {}
        } message: {
            if let message = assignErrorMessage, !message.isEmpty {
                Text(message)
            }
        }
        .bookingTripConfirmDialogs(
            showDeleteConfirmation: $showDeleteConfirmation,
            showRemoveFromTripConfirmation: $showRemoveFromTripConfirmation,
            onConfirmDelete: deletePendingBooking,
            onConfirmRemove: removePendingBookingFromTrip,
            onCancelDelete: { pendingDeleteBookingID = nil },
            onCancelRemove: { pendingRemoveFromTripBookingID = nil }
        )
        .createTripFromBookingsPresentation(
            seed: $tripCreateSeed,
            showFailed: $showCreateTripFromBookingsFailed,
            onSaved: { newTrip in
                onTripCreated?(newTrip.id)
            }
        )
        .sheet(isPresented: $isEditing) {
            if let draftBinding {
                BookingEditorForm(
                    title: L10n.string(.editorEditTitle),
                    showsSyncOverwriteHint: booking?.provider == .manual ? false : true,
                    draft: draftBinding,
                    providerReadOnly: booking?.provider == .manual ? false : true,
                    onCancel: {
                        isEditing = false
                        bookingEditorDraft = nil
                    },
                    onSave: {
                        guard let booking else { return }
                        guard let draft = bookingEditorDraft else { return }
                        try draft.apply(to: booking, in: modelContext)
                        isEditing = false
                        bookingEditorDraft = nil
                    }
                )
                .reisenSheetDetents()
            }
        }
    }
}
