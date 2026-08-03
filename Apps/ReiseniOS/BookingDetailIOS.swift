import SwiftUI
import SwiftData
import WebKit

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenProviders

struct BookingDetailIOS: View {
    let bookingID: UUID

    @Environment(\.modelContext) private var modelContext
    @Query private var bookings: [SDBooking]
    @Query private var trips: [SDTrip]

    @State private var assignErrorMessage: String?
    @State private var showAssignError = false

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
        booking?.title
            ?? booking?.bookingType.displayLabel
            ?? "Buchung"
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
                Label("Bearbeiten", systemImage: "pencil")
            }
            .help("Diese Buchung bearbeiten")

            if booking.provider == .manual {
                Button(role: .destructive) {
                    pendingDeleteBookingID = booking.id
                    showDeleteConfirmation = true
                } label: {
                    Text("Löschen…")
                }
                .help("Diese manuelle Buchung unwiderruflich löschen")
            }

            if booking.trip != nil {
                Button(role: .destructive) {
                    pendingRemoveFromTripBookingID = booking.id
                    showRemoveFromTripConfirmation = true
                } label: {
                    Text("Von Reise entfernen…")
                }
                .help("Diese Buchung aus der Reise lösen und unter „Offene Buchungen“ anzeigen")
            }
        }
    }

    @ViewBuilder
    private func bookingRateSections(for booking: SDBooking) -> some View {
        if let rate = booking.rateDetails {
            Section("Preis / Tarif") {
                BookingRateFieldsView(rate: rate, booking: booking)
            }

            if !rate.resolvedRoomItems.isEmpty {
                Section("Zimmer / Positionen") {
                    BookingRoomItemsView(rate: rate)
                }
            }
        }
    }

    @ViewBuilder
    private func bookingAssignmentSection(for booking: SDBooking) -> some View {
        Section("Zuordnung") {
            if let trip = bookingTrip {
                Text("In Reise: \(trip.title)")
                    .foregroundStyle(.secondary)
            } else if let trip = matchingTrip {
                Button("In Reise zuordnen…") {
                    do {
                        booking.trip = trip
                        try modelContext.save()
                    } catch {
                        assignErrorMessage = error.localizedDescription
                        showAssignError = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .help("Diese offene Buchung der passenden Reise zuordnen")
            } else {
                Text("Keine passende Reise gefunden.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func bookingLinksSection(for booking: SDBooking) -> some View {
        Section("Links") {
            if let externalURL {
                Link("Buchung im Browser öffnen", destination: externalURL)
            } else {
                Text("Kein Browser-Link verfügbar.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func bookingOverviewSection(for booking: SDBooking) -> some View {
        Section("Übersicht") {
            VStack(alignment: .leading, spacing: 6) {
                Text(booking.title ?? booking.bookingType.displayLabel)
                    .font(.headline)
                    .textSelection(.enabled)

                Text("\(booking.bookingType.displayLabel) • \(booking.provider.rawValue.capitalized)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                let startText = booking.startAt.formatted(date: .abbreviated, time: .omitted)
                let endText = booking.endAt.formatted(date: .abbreviated, time: .omitted)
                HStack(spacing: 4) {
                    Text("Zeitraum:")
                    Text(startText)
                    Text("–")
                    Text(endText)
                }
                .foregroundStyle(.secondary)

                if let code = booking.confirmationCode, !code.isEmpty {
                    Text("Bestätigung: \(code)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func bookingTypeDetailsSection(for booking: SDBooking) -> some View {
        let title: String = {
            switch booking.bookingType {
            case .hotel: return "Hotel"
            case .flight: return "Flug"
            case .ferry: return "Fähre"
            case .activity: return "Erlebnis"
            case .other: return "Details"
            }
        }()
        Section(title) {
            BookingScheduleFieldsView(booking: booking)
        }
    }

    @ViewBuilder
    private func bookingSyncStatusSection(for booking: SDBooking) -> some View {
        Section("Sync-Status") {
            if let synced = booking.lastSyncedAt {
                let syncedText = synced.formatted(date: .abbreviated, time: .shortened)
                LabeledContent("Zuletzt synchronisiert", value: syncedText)
            } else {
                Text("Noch nicht synchronisiert.")
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
                        Section("Stornierung") {
                            BookingCancellationDeadlinesView(
                                booking: booking,
                                hotelTimeZone: hotelTimeZone
                            )
                        }
                    }

                    bookingLinksSection(for: booking)

                    bookingSyncStatusSection(for: booking)

                    bookingActionsSection(for: booking)
                }
            } else {
                ContentUnavailableView(
                    "Buchung nicht gefunden",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Die ausgewählte Buchung ist nicht mehr verfügbar.")
                )
            }
        }
        .navigationTitle(bookingNavigationTitle)
        .alert("Zuordnung fehlgeschlagen", isPresented: $showAssignError) {
            Button("OK", role: .cancel) {}
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
        .sheet(isPresented: $isEditing) {
            if let draftBinding {
                BookingEditorForm(
                    title: "Buchung bearbeiten",
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
