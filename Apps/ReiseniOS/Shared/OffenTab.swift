import SwiftUI
import SwiftData

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData

struct OffenTab: View {
    @Binding var sessionChromeEpoch: Int
    #if REISEN_PROVIDER_SYNC
    var onOpenSync: () -> Void
    #endif

    @State private var showCreateTrip = false
    @State private var selectedBookingID: UUID?
    @State private var searchText = ""

    var body: some View {
        AdaptiveListDetail(
            selection: $selectedBookingID,
            list: {
                openBookingsListChrome {
                    #if REISEN_PROVIDER_SYNC
                    OpenBookingsScreen(
                        searchText: $searchText,
                        selectedBookingID: $selectedBookingID,
                        onOpenSync: onOpenSync,
                        onCreateTrip: { showCreateTrip = true }
                    )
                    #else
                    OpenBookingsScreen(
                        searchText: $searchText,
                        selectedBookingID: $selectedBookingID,
                        onCreateTrip: { showCreateTrip = true }
                    )
                    #endif
                }
            },
            detail: { bookingID in
                BookingDetailIOS(bookingID: bookingID)
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
            TripEditorSheet(mode: .create, onSaved: { _ in })
            .reisenSheetDetents()
        }
    }

    @ViewBuilder
    private func openBookingsListChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .navigationTitle(L10n.string(.tabOpen))
            .navigationBarTitleDisplayMode(.inline)
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
}

struct OpenBookingsScreen: View {
    @Binding var searchText: String
    @Binding var selectedBookingID: UUID?
    #if REISEN_PROVIDER_SYNC
    var onOpenSync: () -> Void
    #endif
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
                List(selection: $selectedBookingID) {
                    ForEach(filtered, id: \.id) { booking in
                        bookingRow(booking)
                            .tag(booking.id)
                    }
                }
                .searchable(text: $searchText, prompt: L10n.string(.tripSearchOpenBookings))
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
