import SwiftUI
import SwiftData

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData

struct OffenTab: View {
    @Binding var sessionChromeEpoch: Int
    var onTripCreated: (UUID) -> Void
    #if REISEN_PROVIDER_SYNC
    var onOpenSync: () -> Void
    #endif

    @State private var showCreateTrip = false
    @State private var tripCreateSeed: TripCreateSeed?
    @State private var showCreateTripFromBookingsFailed = false
    @State private var selectedBookingID: UUID?
    @State private var multiSelection = Set<UUID>()
    @State private var isSelectingForTripCreate = false
    @State private var searchText = ""

    var body: some View {
        AdaptiveListDetail(
            selection: $selectedBookingID,
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
    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]
    @Query(sort: \SDTrip.startDate, order: .forward) private var trips: [SDTrip]

    private var openBookings: [SDBooking] {
        OpenBookingMatching.openUnassigned(in: allBookings)
    }

    private var filtered: [SDBooking] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return openBookings }
        return openBookings.filter {
            ($0.title ?? "").localizedCaseInsensitiveContains(q)
                || ($0.confirmationCode ?? "").localizedCaseInsensitiveContains(q)
                || $0.providerRaw.localizedCaseInsensitiveContains(q)
        }
    }

    private var partitioned: (fillable: [(booking: SDBooking, trip: SDTrip)], other: [SDBooking]) {
        OpenBookingMatching.partitionByFillOpportunity(bookings: filtered, trips: trips)
    }

    var body: some View {
        Group {
            if openBookings.isEmpty {
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
            } else if isSelectingForTripCreate {
                List(selection: $multiSelection) {
                    openBookingSections(interactive: false)
                }
                .environment(\.editMode, .constant(.active))
                .searchable(text: $searchText, prompt: L10n.string(.tripSearchOpenBookings))
            } else {
                List(selection: $selectedBookingID) {
                    openBookingSections(interactive: true)
                }
                .searchable(text: $searchText, prompt: L10n.string(.tripSearchOpenBookings))
            }
        }
        .navigationTitle(
            isSelectingForTripCreate && !multiSelection.isEmpty
                ? L10n.format(.tripSelectedOpenBookings, multiSelection.count)
                : L10n.string(.tabOpen)
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleMenu {
            if !isSelectingForTripCreate, !openBookings.isEmpty {
                Button {
                    presentCreateTripFromAllOpen()
                } label: {
                    CreateTripFromAllOpenBookingsLabel(count: openBookings.count)
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
    }

    @ViewBuilder
    private func openBookingSections(interactive: Bool) -> some View {
        let parts = partitioned
        if parts.fillable.isEmpty {
            ForEach(parts.other, id: \.id) { booking in
                openBookingListRow(booking, fillTrip: nil, interactive: interactive)
            }
        } else {
            Section {
                ForEach(parts.fillable, id: \.booking.id) { item in
                    openBookingListRow(item.booking, fillTrip: item.trip, interactive: interactive)
                }
            } header: {
                Text(L10n.string(.tripCompletenessOpenSection))
            } footer: {
                Text(L10n.string(.tripCompletenessOpenSectionFooter))
            }

            if !parts.other.isEmpty {
                Section(L10n.string(.tripCompletenessOpenOtherSection)) {
                    ForEach(parts.other, id: \.id) { booking in
                        openBookingListRow(booking, fillTrip: nil, interactive: interactive)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func openBookingListRow(
        _ booking: SDBooking,
        fillTrip: SDTrip?,
        interactive: Bool
    ) -> some View {
        let caption = fillTrip.map { L10n.tripCompletenessFillCaption(tripTitle: $0.title) }
        Group {
            if interactive {
                bookingRow(booking, fillCaption: caption)
                    .tag(booking.id)
                    .contextMenu {
                        Button {
                            createTripFromBooking(booking.id)
                        } label: {
                            CreateTripFromBookingsLabel()
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
                OpenBookingRow(booking: booking, fillCaption: caption)
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
            OpenBookingRow(booking: booking, fillCaption: fillCaption)
        }
    }
}
