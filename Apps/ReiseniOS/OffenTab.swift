import SwiftUI
import SwiftData

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData

struct OffenTab: View {
    @Binding var sessionChromeEpoch: Int
    var onOpenSync: () -> Void

    @State private var showCreateTrip = false
    @State private var selectedBookingID: UUID?
    @State private var searchText = ""

    var body: some View {
        AdaptiveListDetail(
            selection: $selectedBookingID,
            list: {
                OpenBookingsScreen(
                    searchText: $searchText,
                    selectedBookingID: $selectedBookingID,
                    onOpenSync: onOpenSync,
                    onCreateTrip: { showCreateTrip = true }
                )
                .navigationTitle("Offen")
                .navigationBarTitleDisplayMode(.inline)
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
                        GlobalChromeTrailingToolbar(sessionChromeEpoch: $sessionChromeEpoch)
                    }
                }
            },
            detail: { bookingID in
                BookingDetailIOS(bookingID: bookingID)
            },
            emptyDetail: {
                ContentUnavailableView(
                    "Buchung auswählen",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Wähle eine offene Buchung aus der Liste.")
                )
            }
        )
        .sheet(isPresented: $showCreateTrip) {
            TripEditorSheet(mode: .create, onSaved: { _ in })
            .reisenSheetDetents()
        }
    }
}

struct OpenBookingsScreen: View {
    @Binding var searchText: String
    @Binding var selectedBookingID: UUID?
    var onOpenSync: () -> Void
    var onCreateTrip: () -> Void

    @Environment(\.adaptiveUsesSplitNavigation) private var usesSplit
    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]

    private var openBookings: [SDBooking] {
        allBookings.filter { OpenBookingMatching.isOpenUnassigned($0) }
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

    var body: some View {
        Group {
            if openBookings.isEmpty {
                ContentUnavailableView {
                    Label("Keine offenen Buchungen", systemImage: "calendar")
                } description: {
                    Text("Keine Buchungen ohne Reisezuordnung. Synchronisiere einen Provider oder lege eine Reise an.")
                } actions: {
                    Button("Provider Sync öffnen") { onOpenSync() }
                        .buttonStyle(.borderedProminent)
                    Button("Neue Reise") { onCreateTrip() }
                        .buttonStyle(.bordered)
                }
            } else {
                List(selection: $selectedBookingID) {
                    ForEach(filtered, id: \.id) { booking in
                        bookingRow(booking)
                            .tag(booking.id)
                    }
                }
                .searchable(text: $searchText, prompt: "Offene Buchungen suchen")
            }
        }
        .modifier(CompactUUIDDestination(enabled: !usesSplit) { bookingID in
            BookingDetailIOS(bookingID: bookingID)
        })
    }

    @ViewBuilder
    private func bookingRow(_ booking: SDBooking) -> some View {
        AdaptiveUUIDSelectionRow(id: booking.id, selection: $selectedBookingID, usesSplit: usesSplit) {
            OpenBookingRow(booking: booking)
        }
    }
}

