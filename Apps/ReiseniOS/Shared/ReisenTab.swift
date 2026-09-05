import SwiftUI
import SwiftData

import ReisenAppCore
import ReisenPasteImport
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenDiagnostics

struct ReisenTab: View {
    @Binding var sessionChromeEpoch: Int
    @Binding var selectedTripID: UUID?
    @Binding var compactPushTripID: UUID?
    @Binding var focusBookingID: UUID?
    let pasteImport: PasteImportSession
    #if REISEN_PROVIDER_SYNC
    var onOpenSync: () -> Void
    #endif

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDTrip.startDate, order: .forward) private var trips: [SDTrip]
    @State private var showCreateTrip = false
    @State private var searchText = ""
    @State private var pendingDeleteTrip: SDTrip?
    @State private var showDeleteConfirm = false
    @State private var persistErrorMessage: String?

    private var filteredTrips: [SDTrip] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return trips }
        return trips.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || ($0.destination?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var body: some View {
        AdaptiveListDetail(
            selection: $selectedTripID,
            compactPush: $compactPushTripID,
            list: { tripList },
            detail: { tripID in
                TripDetailIOS(tripID: tripID, focusBookingID: $focusBookingID)
            },
            emptyDetail: {
                ContentUnavailableView(
                    L10n.string(.tripSelectTrip),
                    systemImage: "airplane",
                    description: Text(L10n.string(.tripSelectTripList))
                )
            }
        )
        .sheet(isPresented: $showCreateTrip) {
            TripEditorSheet(
                mode: .create,
                onSaved: { newTrip in
                    selectedTripID = newTrip.id
                }
            )
            .reisenSheetDetents()
        }
        .tripDeleteConfirmDialog(
            isPresented: $showDeleteConfirm,
            tripTitle: pendingDeleteTrip?.title ?? "",
            bookingCount: pendingDeleteTrip?.resolvedBookings.count ?? 0,
            onKeepBookings: {
                if let trip = pendingDeleteTrip { deleteTrip(trip, bookings: .keepAsOpen) }
            },
            onDeleteBookings: {
                if let trip = pendingDeleteTrip { deleteTrip(trip, bookings: .deleteContained) }
            },
            onCancel: { pendingDeleteTrip = nil }
        )
        .persistFailureAlert(message: $persistErrorMessage)
    }

    @ViewBuilder
    private var tripList: some View {
        tripListChrome {
            #if REISEN_PROVIDER_SYNC
            TripListPane(
                trips: trips,
                filteredTrips: filteredTrips,
                searchText: $searchText,
                selectedTripID: $selectedTripID,
                focusBookingID: $focusBookingID,
                onCreateTrip: { showCreateTrip = true },
                onOpenSync: onOpenSync,
                onRequestDelete: { trip in
                    pendingDeleteTrip = trip
                    showDeleteConfirm = true
                }
            )
            #else
            TripListPane(
                trips: trips,
                filteredTrips: filteredTrips,
                searchText: $searchText,
                selectedTripID: $selectedTripID,
                focusBookingID: $focusBookingID,
                onCreateTrip: { showCreateTrip = true },
                onRequestDelete: { trip in
                    pendingDeleteTrip = trip
                    showDeleteConfirm = true
                }
            )
            #endif
        }
    }

    @ViewBuilder
    private func tripListChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .pasteImportToolbar(session: pasteImport, entry: .trip(selectedTripID))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help(L10n.string(.actionCreateTrip))
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

    private func deleteTrip(_ trip: SDTrip, bookings policy: TripDeletionBookingPolicy) {
        do {
            try TripDeletion.perform(trip: trip, in: modelContext, bookings: policy)
            if selectedTripID == trip.id {
                selectedTripID = nil
            }
        } catch {
            Self.recordPersistFailure(operation: "trip_delete", error: error)
            persistErrorMessage = error.localizedDescription
            return
        }
        pendingDeleteTrip = nil
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
                    component: "ReisenTab",
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

private struct TripListPane: View {
    let trips: [SDTrip]
    let filteredTrips: [SDTrip]
    @Binding var searchText: String
    @Binding var selectedTripID: UUID?
    @Binding var focusBookingID: UUID?
    var onCreateTrip: () -> Void
    #if REISEN_PROVIDER_SYNC
    var onOpenSync: () -> Void
    #endif
    var onRequestDelete: (SDTrip) -> Void

    @Environment(\.adaptiveUsesSplitNavigation) private var usesSplit

    var body: some View {
        Group {
            if trips.isEmpty {
                ContentUnavailableView {
                    Label(L10n.string(.tripNoTrips), systemImage: "airplane")
                } description: {
                    Text(L10n.string(.tripNoTripsHint))
                } actions: {
                    Button(L10n.string(.actionNewTrip)) { onCreateTrip() }
                        .buttonStyle(.borderedProminent)
                    #if REISEN_PROVIDER_SYNC
                    Button(L10n.string(.actionOpenProviderSync)) { onOpenSync() }
                        .buttonStyle(.bordered)
                    #endif
                }
            } else {
                let currentTrips = filteredTrips.filter { !$0.isElapsed() }
                let elapsedTrips = filteredTrips.filter { $0.isElapsed() }
                let gapBadges = SDTrip.listGapBadgeCounts(for: filteredTrips)
                List(selection: $selectedTripID) {
                    ForEach(currentTrips) { trip in
                        tripRow(trip, gapCount: gapBadges[trip.id])
                            .tag(trip.id)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(L10n.string(.commonDelete), role: .destructive) {
                                    onRequestDelete(trip)
                                }
                            }
                    }
                    if !elapsedTrips.isEmpty {
                        Section(L10n.string(.bookingElapsed)) {
                            ForEach(elapsedTrips) { trip in
                                tripRow(trip, gapCount: gapBadges[trip.id])
                                    .tag(trip.id)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(L10n.string(.commonDelete), role: .destructive) {
                                            onRequestDelete(trip)
                                        }
                                    }
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: L10n.string(.tripSearchTrips))
            }
        }
        .navigationTitle(L10n.string(.tabTrips))
        .modifier(CompactUUIDDestination(enabled: !usesSplit) { tripID in
            TripDetailIOS(tripID: tripID, focusBookingID: $focusBookingID)
        })
    }

    @ViewBuilder
    private func tripRow(_ trip: SDTrip, gapCount: Int?) -> some View {
        AdaptiveUUIDSelectionRow(id: trip.id, selection: $selectedTripID, usesSplit: usesSplit) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.title)
                        .font(.headline)
                    Text(TripDateBounds.formattedAbbreviatedRange(start: trip.startDate, end: trip.endDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let gapCount {
                    TripCompletenessListAccessory(gapCount: gapCount)
                }
            }
        }
    }
}
