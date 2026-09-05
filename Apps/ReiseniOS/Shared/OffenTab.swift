import SwiftUI
import SwiftData

import ReisenAppCore
import ReisenPasteImport
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenDiagnostics

struct OffenTab: View {
    @Binding var sessionChromeEpoch: Int
    @Binding var selectedBookingID: UUID?
    @Binding var compactPushBookingID: UUID?
    let pasteImport: PasteImportSession
    var onTripCreated: (UUID) -> Void
    #if REISEN_PROVIDER_SYNC
    var onOpenSync: () -> Void
    #endif

    @State private var showCreateTrip = false
    @State private var tripCreateSeed: TripCreateSeed?
    @State private var showCreateTripFromBookingsFailed = false
    @State private var multiSelection = Set<UUID>()
    @State private var isSelectingForTripCreate = false
    @State private var searchText = ""

    var body: some View {
        AdaptiveListDetail(
            selection: $selectedBookingID,
            compactPush: $compactPushBookingID,
            list: { openBookingsScreen },
            detail: { bookingID in
                BookingDetailIOS(bookingID: bookingID, onTripCreated: onTripCreated)
            },
            emptyDetail: {
                ContentUnavailableView(
                    L10n.string(.tripSelectOpenBooking),
                    systemImage: "list.bullet.rectangle",
                    description: Text(L10n.string(.tripSelectOpenBookingList))
                )
            }
        )
        .sheet(isPresented: $showCreateTrip) {
            TripEditorSheet(mode: .create, onSaved: { trip in
                onTripCreated(trip.id)
            })
            .reisenSheetDetents()
        }
        .createTripFromBookingsPresentation(
            seed: $tripCreateSeed,
            showFailed: $showCreateTripFromBookingsFailed,
            onSaved: { trip in
                onTripCreated(trip.id)
            }
        )
    }

    @ViewBuilder
    private var openBookingsScreen: some View {
        openBookingsList
            .pasteImportToolbar(session: pasteImport, entry: .open)
    }

    @ViewBuilder
    private var openBookingsList: some View {
        #if REISEN_PROVIDER_SYNC
        OpenBookingsScreen(
            searchText: $searchText,
            selectedBookingID: $selectedBookingID,
            multiSelection: $multiSelection,
            isSelectingForTripCreate: $isSelectingForTripCreate,
            tripCreateSeed: $tripCreateSeed,
            showCreateTripFromBookingsFailed: $showCreateTripFromBookingsFailed,
            sessionChromeEpoch: $sessionChromeEpoch,
            onOpenSync: onOpenSync,
            onCreateTrip: { showCreateTrip = true },
            onTripCreated: onTripCreated
        )
        #else
        OpenBookingsScreen(
            searchText: $searchText,
            selectedBookingID: $selectedBookingID,
            multiSelection: $multiSelection,
            isSelectingForTripCreate: $isSelectingForTripCreate,
            tripCreateSeed: $tripCreateSeed,
            showCreateTripFromBookingsFailed: $showCreateTripFromBookingsFailed,
            onCreateTrip: { showCreateTrip = true },
            onTripCreated: onTripCreated
        )
        #endif
    }
}

struct OpenBookingsScreen: View {
    @Binding var searchText: String
    @Binding var selectedBookingID: UUID?
    @Binding var multiSelection: Set<UUID>
    @Binding var isSelectingForTripCreate: Bool
    @Binding var tripCreateSeed: TripCreateSeed?
    @Binding var showCreateTripFromBookingsFailed: Bool
    #if REISEN_PROVIDER_SYNC
    @Binding var sessionChromeEpoch: Int
    var onOpenSync: () -> Void
    #endif
    var onCreateTrip: () -> Void
    var onTripCreated: (UUID) -> Void

    @Environment(\.adaptiveUsesSplitNavigation) private var usesSplit
    @Environment(\.providerNativeAppPresence) private var nativeAppPresence
    @Environment(\.providerSessionHub) private var sessionHub
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @State private var cancelRequest: BookingPortalCancelRequest?
    @State private var pendingDeleteBooking: SDBooking?
    @State private var showDeleteConfirmation = false
    @State private var persistErrorMessage: String?
    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]
    @Query(sort: \SDTrip.startDate, order: .forward) private var trips: [SDTrip]

    private var currentOpenBookings: [SDBooking] {
        OpenBookingMatching.currentUnassigned(in: allBookings)
    }

    private var elapsedOpenBookings: [SDBooking] {
        OpenBookingMatching.elapsedUnassigned(in: allBookings)
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

    private var openBookings: [SDBooking] {
        currentOpenBookings
    }

    private var filtered: [SDBooking] {
        matching(openBookings)
    }

    private var filteredElapsed: [SDBooking] {
        matching(elapsedOpenBookings)
    }

    private func matching(_ bookings: [SDBooking]) -> [SDBooking] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return bookings }
        return bookings.filter {
            ($0.title ?? "").localizedCaseInsensitiveContains(q)
                || ($0.confirmationCode ?? "").localizedCaseInsensitiveContains(q)
                || $0.providerRaw.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        Group {
            if currentOpenBookings.isEmpty && elapsedOpenBookings.isEmpty {
                ContentUnavailableView {
                    Label(L10n.string(.tripNoOpenBookings), systemImage: "calendar")
                } description: {
                    Text(L10n.string(.tripNoOpenBookingsHint))
                } actions: {
                    #if REISEN_PROVIDER_SYNC
                    Button(L10n.string(.actionOpenProviderSync)) { onOpenSync() }
                        .buttonStyle(.borderedProminent)
                    #endif
                    Button(L10n.string(.actionNewTrip)) { onCreateTrip() }
                        #if REISEN_PROVIDER_SYNC
                        .buttonStyle(.bordered)
                        #else
                        .buttonStyle(.borderedProminent)
                        #endif
                }
            } else {
                if isSelectingForTripCreate {
                    List(selection: $multiSelection) {
                        openBookingListContent(interactive: false)
                    }
                    .environment(\.editMode, .constant(.active))
                    .searchable(text: $searchText, prompt: L10n.string(.tripSearchOpenBookings))
                } else {
                    List(selection: $selectedBookingID) {
                        openBookingListContent(interactive: true)
                    }
                    .searchable(text: $searchText, prompt: L10n.string(.tripSearchOpenBookings))
                }
            }
        }
        .navigationTitle(
            isSelectingForTripCreate && !multiSelection.isEmpty
                ? L10n.format(.tripSelectedOpenBookings, multiSelection.count)
                : L10n.string(.tabOpen)
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleMenu {
            let fromAll = OpenBookingMatching.openUnassigned(in: allBookings)
            if !isSelectingForTripCreate, !fromAll.isEmpty {
                Button {
                    presentCreateTripFromAllOpen()
                } label: {
                    CreateTripFromAllOpenBookingsLabel(count: fromAll.count)
                }
            }
        }
        .toolbar {
            if isSelectingForTripCreate {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.commonCancel)) {
                        isSelectingForTripCreate = false
                        multiSelection = []
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        presentCreateTripFromSelection(multiSelection)
                    } label: {
                        CreateTripFromBookingsLabel()
                    }
                    .disabled(multiSelection.isEmpty)
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onCreateTrip()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help(L10n.string(.actionCreateTrip))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.string(.commonSelect)) {
                        isSelectingForTripCreate = true
                    }
                }
                #if REISEN_PROVIDER_SYNC
                ToolbarItem(placement: .topBarTrailing) {
                    GlobalChromeTrailingToolbar(
                        sessionChromeEpoch: $sessionChromeEpoch
                    )
                }
                #endif
            }
        }
        .modifier(CompactUUIDDestination(enabled: !usesSplit && !isSelectingForTripCreate) { bookingID in
            BookingDetailIOS(bookingID: bookingID, onTripCreated: onTripCreated)
        })
        .bookingPortalCancelSheet($cancelRequest)
        .bookingDeleteConfirmAlert(
            isPresented: $showDeleteConfirmation,
            bookingTitle: pendingDeleteBooking?.presentationTitle ?? L10n.string(.editorBooking),
            showsSyncRestoreWarning: pendingDeleteBooking.map { $0.provider != .manual } ?? false,
            onConfirm: deletePendingBooking,
            onCancel: { pendingDeleteBooking = nil }
        )
        .persistFailureAlert(message: $persistErrorMessage)
    }

    private func requestDeleteBooking(_ booking: SDBooking) {
        pendingDeleteBooking = booking
        showDeleteConfirmation = true
    }

    private func deletePendingBooking() {
        guard let booking = pendingDeleteBooking else { return }
        do {
            try BookingDeletion.perform(booking: booking, in: modelContext)
            if selectedBookingID == booking.id {
                selectedBookingID = nil
            }
            multiSelection.remove(booking.id)
        } catch {
            Self.recordPersistFailure(operation: "booking_delete", error: error)
            persistErrorMessage = error.localizedDescription
        }
        pendingDeleteBooking = nil
    }

    @ViewBuilder
    private func openBookingListContent(interactive: Bool) -> some View {
        let partition = OpenBookingMatching.partitionByFillOpportunity(
            bookings: filtered,
            trips: trips
        )
        openBookingSections(partition: partition, interactive: interactive)
        if !filteredElapsed.isEmpty {
            Section(L10n.string(.bookingElapsed)) {
                ForEach(filteredElapsed, id: \.id) { booking in
                    openBookingListRow(booking, fillCaption: nil, interactive: interactive)
                }
            }
        }
    }

    @ViewBuilder
    private func openBookingSections(
        partition: OpenBookingFillPartition,
        interactive: Bool
    ) -> some View {
        OpenBookingsFillSections(partition: partition) { booking, fillCaption in
            openBookingListRow(booking, fillCaption: fillCaption, interactive: interactive)
        }
    }

    @ViewBuilder
    private func openBookingListRow(
        _ booking: SDBooking,
        fillCaption: String?,
        interactive: Bool
    ) -> some View {
        Group {
            if interactive {
                bookingRow(booking, fillCaption: fillCaption)
                    .tag(booking.id)
                    .contextMenu {
                        BookingCopyConfirmationMenuItems(booking: booking)
                        Button {
                            createTripFromBooking(booking.id)
                        } label: {
                            CreateTripFromBookingsLabel()
                        }
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
                        Divider()
                        Button(L10n.string(.actionDeleteEllipsis), role: .destructive) {
                            requestDeleteBooking(booking)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(L10n.string(.commonDelete), role: .destructive) {
                            requestDeleteBooking(booking)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if !usesSplit {
                            Button {
                                createTripFromBooking(booking.id)
                            } label: {
                                CreateTripFromBookingsLabel()
                            }
                            .tint(.accentColor)
                        }
                    }
            } else {
                OpenBookingRow(
                    booking: booking,
                    fillCaption: fillCaption,
                    partnerTitles: overlapPartnerTitles(for: booking.id)
                )
                    .tag(booking.id)
            }
        }
    }

    private func createTripFromBooking(_ bookingID: UUID) {
        presentCreateTripFromSelection(Set([bookingID]))
    }

    private func presentCreateTripFromSelection(_ bookingIDs: Set<UUID>) {
        guard OpenBookingCreateTripAction.assignSeed(
            fromIDs: bookingIDs,
            in: openBookings,
            seed: $tripCreateSeed,
            showFailed: $showCreateTripFromBookingsFailed
        ) else { return }
        isSelectingForTripCreate = false
        multiSelection = []
    }

    private func presentCreateTripFromAllOpen() {
        guard OpenBookingCreateTripAction.assignSeedFromAll(
            in: allBookings,
            seed: $tripCreateSeed,
            showFailed: $showCreateTripFromBookingsFailed
        ) else { return }
        isSelectingForTripCreate = false
        multiSelection = []
    }

    @ViewBuilder
    private func bookingRow(_ booking: SDBooking, fillCaption: String? = nil) -> some View {
        AdaptiveUUIDSelectionRow(id: booking.id, selection: $selectedBookingID, usesSplit: usesSplit) {
            OpenBookingRow(
                booking: booking,
                fillCaption: fillCaption,
                partnerTitles: overlapPartnerTitles(for: booking.id)
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
                    component: "OffenTab",
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
