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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.providerSessionHub) private var sessionHub
    @Environment(\.openURL) private var openURL
    @Query private var bookings: [SDBooking]
    @Query private var trips: [SDTrip]

    @State private var assignErrorMessage: String?
    @State private var showAssignError = false
    @State private var persistErrorMessage: String?
    @State private var tripCreateSeed: TripCreateSeed?
    @State private var showCreateTripFromBookingsFailed = false

    @State private var isEditing = false
    @State private var bookingEditorDraft: BookingEditorDraft?

    @State private var pendingDeleteBookingID: UUID?
    @State private var showDeleteConfirmation = false

    @State private var pendingRemoveFromTripBookingID: UUID?
    @State private var showRemoveFromTripConfirmation = false
    @State private var cancelRequest: BookingPortalCancelRequest?

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
        do {
            try BookingDeletion.perform(booking: bookingToDelete, in: modelContext)
            pendingDeleteBookingID = nil
            dismiss()
        } catch {
            persistErrorMessage = error.localizedDescription
            pendingDeleteBookingID = nil
        }
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

            Button(role: .destructive) {
                pendingDeleteBookingID = booking.id
                showDeleteConfirmation = true
            } label: {
                Text(L10n.string(.actionDeleteEllipsis))
            }
            .help(L10n.string(.bookingDeleteHelp))

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
                ForEach(BookingRateFields.make(rate: rate, booking: booking)) { field in
                    CopyableLabeledValue(field: field, style: .list)
                }
            }

            if !rate.resolvedRoomItems.isEmpty {
                Section(BookingDetailLabels.roomItemsSection) {
                    ForEach(
                        rate.resolvedRoomItems.sorted(by: { ($0.sortIndex ?? 0) < ($1.sortIndex ?? 0) })
                    ) { item in
                        BookingRoomItemRow(
                            item: item,
                            rateCurrency: rate.totalPriceCurrency,
                            style: .list
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bookingAssignmentSection(for booking: SDBooking) -> some View {
        Section(L10n.string(.tripAssign)) {
            if let trip = bookingTrip {
                CopyableLabeledValue(
                    label: L10n.string(.tripNameField),
                    value: trip.title,
                    style: .list
                )
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
        let hasSession = sessionHub.hasSessionWebView(for: booking)
        Section(L10n.string(.bookingDetailLinksSection)) {
            if BookingPortalActionBar.isVisible(
                booking: booking,
                hasSessionWebView: hasSession
            ) {
                BookingPortalActionBar(
                    booking: booking,
                    openTitle: BookingPortalOpenTitle.short,
                    openHelp: BookingPortalOpenTitle.openInBrowserHelp,
                    openButtonStyle: .prominent,
                    showsCopyMenu: true,
                    hasSessionWebView: hasSession,
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
            } else {
                Text(L10n.string(.bookingDetailNoBrowserLink))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func bookingOverviewSection(for booking: SDBooking) -> some View {
        Section(L10n.string(.tripOverview)) {
            CopyableLabeledValue(
                label: L10n.string(.editorTitle),
                value: booking.presentationTitle,
                style: .list,
                valueTextStyle: .headline
            )
            CopyableLabeledValue(
                label: L10n.string(.editorType),
                value: booking.bookingType.displayLabel,
                style: .list
            )
            CopyableLabeledValue(
                label: L10n.string(.editorProvider),
                value: booking.provider.rawValue.capitalized,
                style: .list
            )
            CopyableLabeledValue(
                label: BookingDetailLabels.dateRange,
                value: BookingScheduleRangeText.make(for: booking),
                style: .list
            )
            BookingElapsedLabel(for: booking)
        }
    }

    @ViewBuilder
    private func bookingTypeDetailsSection(for booking: SDBooking) -> some View {
        Section(booking.bookingType.displayLabel) {
            ForEach(BookingScheduleFields.make(booking: booking)) { field in
                CopyableLabeledValue(field: field, style: .list)
            }
        }
    }

    @ViewBuilder
    private func bookingSyncStatusSection(for booking: SDBooking) -> some View {
        Section(L10n.string(.bookingDetailSyncStatusSection)) {
            if let synced = booking.lastSyncedAt {
                let syncedText = synced.formatted(date: .abbreviated, time: .shortened)
                CopyableLabeledValue(
                    label: L10n.string(.tripLastSynced),
                    value: syncedText,
                    kind: .standard,
                    style: .list
                )
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
                            ForEach(
                                booking.resolvedCancellationDeadlines.sorted(by: { $0.deadlineAt < $1.deadlineAt }),
                                id: \.id
                            ) { deadline in
                                BookingCancellationDeadlineRow(
                                    deadline: deadline,
                                    feeCurrency: booking.rateDetails?.totalPriceCurrency,
                                    hotelTimeZone: hotelTimeZone,
                                    style: .list
                                )
                            }
                        }
                    }

                    if !booking.resolvedGuestHints.isEmpty {
                        Section(GuestHintCategory.preTravelImportant.displayTitle) {
                            ForEach(
                                booking.resolvedGuestHints.sorted(by: { $0.title < $1.title }),
                                id: \.id
                            ) { hint in
                                BookingGuestHintRow(hint: hint, style: .list)
                            }
                        }
                    }

                    bookingLinksSection(for: booking)

                    bookingSyncStatusSection(for: booking)

                    bookingActionsSection(for: booking)
                }
                .id(booking.id)
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
        .persistFailureAlert(message: $persistErrorMessage)
        .bookingTripConfirmDialogs(
            showDeleteConfirmation: $showDeleteConfirmation,
            showRemoveFromTripConfirmation: $showRemoveFromTripConfirmation,
            bookingTitle: booking?.presentationTitle ?? L10n.string(.editorBooking),
            showsSyncRestoreWarning: booking.map { $0.provider != .manual } ?? false,
            onConfirmDelete: deletePendingBooking,
            onConfirmRemove: removePendingBookingFromTrip,
            onCancelDelete: { pendingDeleteBookingID = nil },
            onCancelRemove: { pendingRemoveFromTripBookingID = nil }
        )
        .bookingPortalCancelSheet($cancelRequest)
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
