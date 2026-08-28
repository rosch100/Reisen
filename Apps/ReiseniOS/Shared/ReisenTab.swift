import SwiftUI
import SwiftData

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData

struct ReisenTab: View {
    @Binding var sessionChromeEpoch: Int
    @Binding var selectedTripID: UUID?
    let pasteImport: PasteImportIOSSession
    #if REISEN_PROVIDER_SYNC
    var onOpenSync: () -> Void
    #endif

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDTrip.startDate, order: .forward) private var trips: [SDTrip]
    @State private var showCreateTrip = false
    @State private var searchText = ""
    @State private var pendingDeleteTrip: SDTrip?
    @State private var showDeleteConfirm = false

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
            list: { tripList },
            detail: { tripID in
                TripDetailIOS(tripID: tripID)
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
        .confirmationDialog(
            L10n.string(.actionDeleteTripConfirm),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible,
            presenting: pendingDeleteTrip
        ) { trip in
            Button(L10n.string(.commonDelete), role: .destructive) {
                deleteTrip(trip)
            }
            Button(L10n.string(.commonCancel), role: .cancel) {
                pendingDeleteTrip = nil
            }
        } message: { _ in
            Text(TripDeletion.confirmationMessage)
        }
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
            .pasteImportToolbar(session: pasteImport)
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

    private func deleteTrip(_ trip: SDTrip) {
        do {
            try TripDeletion.perform(trip: trip, in: modelContext)
            if selectedTripID == trip.id {
                selectedTripID = nil
            }
        } catch {
            // Keep selection; error surfaces on next interaction if save failed.
        }
        pendingDeleteTrip = nil
    }
}

private struct TripListPane: View {
    let trips: [SDTrip]
    let filteredTrips: [SDTrip]
    @Binding var searchText: String
    @Binding var selectedTripID: UUID?
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
                List(selection: $selectedTripID) {
                    ForEach(filteredTrips) { trip in
                        tripRow(trip)
                            .tag(trip.id)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(L10n.string(.commonDelete), role: .destructive) {
                                    onRequestDelete(trip)
                                }
                            }
                    }
                }
                .searchable(text: $searchText, prompt: L10n.string(.tripSearchTrips))
            }
        }
        .navigationTitle(L10n.string(.tabTrips))
        .modifier(CompactUUIDDestination(enabled: !usesSplit) { tripID in
            TripDetailIOS(tripID: tripID)
        })
    }

    @ViewBuilder
    private func tripRow(_ trip: SDTrip) -> some View {
        AdaptiveUUIDSelectionRow(id: trip.id, selection: $selectedTripID, usesSplit: usesSplit) {
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.title)
                    .font(.headline)
                Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
