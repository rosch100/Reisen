import SwiftUI
import SwiftData

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData

struct ReisenTab: View {
    @Binding var sessionChromeEpoch: Int
    var onOpenSync: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDTrip.startDate, order: .forward) private var trips: [SDTrip]
    @State private var showCreateTrip = false
    @State private var selectedTripID: UUID?
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
                    "Reise auswählen",
                    systemImage: "airplane",
                    description: Text("Wähle eine Reise aus der Liste oder lege eine neue an.")
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
            "Reise löschen?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible,
            presenting: pendingDeleteTrip
        ) { trip in
            Button("Löschen", role: .destructive) {
                deleteTrip(trip)
            }
            Button("Abbrechen", role: .cancel) {
                pendingDeleteTrip = nil
            }
        } message: { _ in
            Text(TripDeletion.confirmationMessage)
        }
    }

    @ViewBuilder
    private var tripList: some View {
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateTrip = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Neue Reise anlegen")
            }
            ToolbarItem(placement: .topBarTrailing) {
                GlobalChromeTrailingToolbar(
                    sessionChromeEpoch: $sessionChromeEpoch
                )
            }
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
    var onOpenSync: () -> Void
    var onRequestDelete: (SDTrip) -> Void

    @Environment(\.adaptiveUsesSplitNavigation) private var usesSplit

    var body: some View {
        Group {
            if trips.isEmpty {
                ContentUnavailableView {
                    Label("Keine Reisen", systemImage: "airplane")
                } description: {
                    Text("Lege eine Reise an oder synchronisiere Buchungen von einem Provider.")
                } actions: {
                    Button("Neue Reise") { onCreateTrip() }
                        .buttonStyle(.borderedProminent)
                    Button("Provider Sync öffnen") { onOpenSync() }
                        .buttonStyle(.bordered)
                }
            } else {
                List(selection: $selectedTripID) {
                    ForEach(filteredTrips) { trip in
                        tripRow(trip)
                            .tag(trip.id)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Löschen", role: .destructive) {
                                    onRequestDelete(trip)
                                }
                            }
                    }
                }
                .searchable(text: $searchText, prompt: "Reisen suchen")
            }
        }
        .navigationTitle("Reisen")
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
