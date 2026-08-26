import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData
import ReisenSharedUI
import ReisenProviders
import AppKit
import Foundation

struct TripDetailView: View {
    enum Mode {
        case list
        case detail
    }

    let mode: Mode
    @Bindable var trip: SDTrip
    @Binding var selectedTimelineID: String?
    @Binding var gapEditorPayload: GapEditorPayload?
    @Binding var bookingEditorSession: BookingEditorSession?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]
    @Query(sort: \SDGap.gapStart, order: .forward) private var allGaps: [SDGap]

    private var sortedBookings: [SDBooking] {
        trip.timelineBookings()
    }

    private var tripTotalPriceText: String {
        let bookingAmounts = sortedBookings.compactMap { $0.rateDetails?.totalPriceAmount }

        let gapAmounts = gaps.compactMap { gap in
            savedGapsByKey[gap.identityKey]?.priceAmount
        }

        let amounts = bookingAmounts + gapAmounts
        guard !amounts.isEmpty else { return "k.A." }

        let bookingCurrency = sortedBookings.compactMap { $0.rateDetails?.totalPriceCurrency }.first
        let gapCurrency = gaps.compactMap { gap in
            savedGapsByKey[gap.identityKey]?.priceCurrencyCode
        }.first

        let currency = bookingCurrency ?? gapCurrency
        let total = amounts.reduce(0, +)
        return Formatting.formatCurrencyAmount(total, currencyCode: currency)
    }

    private var savedGapsByKey: [String: SDGap] {
        TripGapTimeline.savedGapsByKey(allGaps: allGaps, tripID: trip.id)
    }

    private var overlapCountsByBookingID: [UUID: Int] {
        BookingDayOverlap.countsByID(sortedBookings.map(\.daySpan))
    }

    private var gaps: [ComputedGap] {
        TripGapTimeline.computedGaps(trip: trip, bookings: sortedBookings)
    }

    private func selectTimelineID(_ id: String) {
        selectedTimelineID = id
    }

    private func editBooking(_ booking: SDBooking) {
        selectTimelineID(booking.id.uuidString)
        bookingEditorSession = .edit(bookingID: booking.id)
    }

    private func startCreateBooking(prefillStart: Date?, prefillEnd: Date?, selectID: String?) {
        if let selectID { selectTimelineID(selectID) }
        bookingEditorSession = .create(prefillStart: prefillStart, prefillEnd: prefillEnd)
    }

    private func removeBookingFromTrip(_ booking: SDBooking, fallbackTimelineID: String?) {
        booking.trip = nil
        try? modelContext.save()

        let removedID = booking.id.uuidString
        if selectedTimelineID == removedID {
            selectedTimelineID = (removedID == fallbackTimelineID) ? nil : fallbackTimelineID
        }

        if case .edit(let editingID) = bookingEditorSession,
           editingID == booking.id {
            bookingEditorSession = nil
        }
    }

    private func requestDeleteManualBooking(_ booking: SDBooking) {
        selectTimelineID(booking.id.uuidString)
        pendingManualDeleteBookingID = booking.id
        showManualDeleteConfirmation = true
    }

    private func requestRemoveBookingFromTrip(_ booking: SDBooking) {
        selectTimelineID(booking.id.uuidString)
        pendingRemoveFromTripBookingID = booking.id
        showRemoveFromTripConfirmation = true
    }

    @State private var showAssignBookings = false
    @State private var pendingManualDeleteBookingID: UUID?
    @State private var showManualDeleteConfirmation = false
    @State private var pendingRemoveFromTripBookingID: UUID?
    @State private var showRemoveFromTripConfirmation = false


    private func confirmDeleteManualBooking() {
        guard let bookingIDToDelete = pendingManualDeleteBookingID else { return }

        if let bookingToDelete = trip.resolvedBookings.first(where: { $0.id == bookingIDToDelete }) {
            modelContext.delete(bookingToDelete)
            try? modelContext.save()
        }

        let newSelection = trip.timelineBookings().first?.id.uuidString

        if selectedTimelineID == bookingIDToDelete.uuidString {
            selectedTimelineID = newSelection
        }

        if case .edit(let editingID) = bookingEditorSession,
           editingID == bookingIDToDelete {
            bookingEditorSession = nil
        }

        pendingManualDeleteBookingID = nil
    }

    private func confirmRemoveBookingFromTrip() {
        guard let bookingID = pendingRemoveFromTripBookingID,
              let booking = trip.resolvedBookings.first(where: { $0.id == bookingID }) else { return }
        let fallbackTimelineID = sortedBookings.first(where: { $0.id != bookingID })?.id.uuidString
        removeBookingFromTrip(booking, fallbackTimelineID: fallbackTimelineID)
        pendingRemoveFromTripBookingID = nil
    }

    var body: some View {
        let timelineItems = timelineItems(gaps: gaps, bookings: sortedBookings)
        let selectedTimelineItem: TripTimelineItem? = {
            guard let selectedTimelineID else { return nil }
            return timelineItems.first { $0.id == selectedTimelineID }
        }()

        // Für Mail-ähnliches UX: bei leerer Selektion automatisch erste passende Buchung auswählen.
        let firstBookingTimelineID: String? = timelineItems.first {
            if case .booking = $0 { return true }
            return false
        }?.id

        Group {
        if mode == .list {
            VStack(alignment: .leading, spacing: 0) {
                tripOverviewSection
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Text("Buchungen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                    .fixedSize(horizontal: false, vertical: true)

                if timelineItems.isEmpty {
                    ContentUnavailableView {
                        Label("Keine Buchungen", systemImage: "calendar.badge.exclamationmark")
                    } description: {
                        Text("Dieser Reise sind noch keine zukünftigen Buchungen zugeordnet.")
                    } actions: {
                        Button("Buchung hinzufügen…") {
                            startCreateBooking(prefillStart: nil, prefillEnd: nil, selectID: nil)
                        }
                        Button("Buchungen zuordnen…") {
                            showAssignBookings = true
                        }
                        .disabled(openBookingsCandidates().isEmpty)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    bookingsList(timelineItems: timelineItems, fallbackTimelineID: firstBookingTimelineID)
                }
            }
            .navigationTitle(trip.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Buchungen zuordnen…") {
                        showAssignBookings = true
                    }
                    .disabled(openBookingsCandidates().isEmpty)
                    .help(openBookingsCandidates().isEmpty
                        ? "Keine offenen Buchungen im Reisezeitraum"
                        : "Offene Buchungen dieser Reise zuordnen")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Buchung hinzufügen…") {
                        startCreateBooking(prefillStart: nil, prefillEnd: nil, selectID: nil)
                    }
                    .help("Manuelle Buchung für diese Reise anlegen")
                }
            }
            .sheet(isPresented: $showAssignBookings) {
                AssignBookingsSheet(
                    trip: trip,
                    candidates: openBookingsCandidates()
                )
            }
            .onAppear {
                guard selectedTimelineID == nil else { return }
                selectedTimelineID = firstBookingTimelineID
            }
            .onChange(of: trip.id) { _, _ in
                bookingEditorSession = nil
                guard selectedTimelineID == nil else { return }
                selectedTimelineID = firstBookingTimelineID
            }
            .onReceive(NotificationCenter.default.publisher(for: .reisenAssignBookings)) { _ in
                guard !openBookingsCandidates().isEmpty else { return }
                showAssignBookings = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .reisenAddBooking)) { _ in
                startCreateBooking(
                    prefillStart: nil,
                    prefillEnd: nil,
                    selectID: selectedTimelineID
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .reisenRequestRemoveBookingFromTrip)) { note in
                guard let bookingID = note.object as? UUID,
                      let booking = trip.resolvedBookings.first(where: { $0.id == bookingID }) else { return }
                requestRemoveBookingFromTrip(booking)
            }
            .onReceive(NotificationCenter.default.publisher(for: .reisenRequestDeleteManualBooking)) { note in
                guard let bookingID = note.object as? UUID,
                      let booking = trip.resolvedBookings.first(where: { $0.id == bookingID }),
                      booking.provider == .manual else { return }
                requestDeleteManualBooking(booking)
            }
        } else {
            BookingDetailPanel(
                selectedTimelineItem: selectedTimelineItem,
                trip: trip,
                overlapCountsByBookingID: overlapCountsByBookingID,
                bookingEditorSession: $bookingEditorSession,
                selectedTimelineID: $selectedTimelineID,
                onEditGap: { payload in gapEditorPayload = payload },
                    gapPresentation: gapPresentation(for:),
                    onRequestManualDeleteBooking: { bookingID in
                        pendingManualDeleteBookingID = bookingID
                        showManualDeleteConfirmation = true
                    },
                    onRequestRemoveFromTrip: { bookingID in
                        guard let booking = trip.resolvedBookings.first(where: { $0.id == bookingID }) else { return }
                        requestRemoveBookingFromTrip(booking)
                    }
            )
            .navigationTitle(trip.title)
            .sheet(item: $gapEditorPayload) { payload in
                GapEditorSheet(payload: payload) { newTitle, newKind, newPriceAmount, newCurrencyCode in
                    do {
                        try GapPersistence.upsert(
                            payload: payload,
                            title: newTitle,
                            kind: newKind,
                            price: newPriceAmount,
                            currency: newCurrencyCode,
                            trip: trip,
                            bookings: sortedBookings,
                            existing: savedGapsByKey[payload.key],
                            context: modelContext
                        )
                    } catch {
                        assertionFailure("Gap save failed: \(error)")
                    }
                    gapEditorPayload = nil
                }
            }
        }
        }
        .bookingTripConfirmDialogs(
            showDeleteConfirmation: $showManualDeleteConfirmation,
            showRemoveFromTripConfirmation: $showRemoveFromTripConfirmation,
            onConfirmDelete: confirmDeleteManualBooking,
            onConfirmRemove: confirmRemoveBookingFromTrip,
            onCancelDelete: { pendingManualDeleteBookingID = nil },
            onCancelRemove: { pendingRemoveFromTripBookingID = nil }
        )
    }

    @ViewBuilder
    private func bookingsList(
        timelineItems: [TripTimelineItem],
        fallbackTimelineID: String?
    ) -> some View {
        // Keine SwiftUI-List/Table: deren Scroll-vs.-Tap-Erkennung verzögert Klicks
        // und lässt sie manchmal ausfallen. ScrollView + plain Button = sofortige Selektion.
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(timelineItems) { item in
                        Button {
                            selectedTimelineID = item.id
                        } label: {
                            TimelineRowLabel(
                                item: item,
                                overlapCountsByBookingID: overlapCountsByBookingID,
                                gapPresentation: gapPresentation(for:),
                                onEditGap: { payload in
                                    gapEditorPayload = payload
                                }
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                selectedTimelineID == item.id
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(item.id)
                        .contextMenu {
                            switch item {
                            case .booking(let booking):
                                Button("Bearbeiten") { editBooking(booking) }
                                Button("Buchung hinzufügen…") {
                                    startCreateBooking(
                                        prefillStart: nil,
                                        prefillEnd: nil,
                                        selectID: booking.id.uuidString
                                    )
                                }
                                if let url = booking.browserURL {
                                    Button("Buchung im Browser öffnen") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                Button(role: .destructive) {
                                    requestRemoveBookingFromTrip(booking)
                                } label: {
                                    Text("Von Reise entfernen…")
                                }

                                if ProviderID(rawValue: booking.providerRaw) == .manual {
                                    Button(role: .destructive) { requestDeleteManualBooking(booking) } label: {
                                        Text("Löschen…")
                                    }
                                }

                            case .gap(let gap):
                                let editPayload = gapPresentation(for: gap).editorPayload(for: gap)

                                Button("Lücke bearbeiten…") {
                                    selectTimelineID(item.id)
                                    gapEditorPayload = editPayload
                                }
                                Button("Buchung hinzufügen…") {
                                    startCreateBooking(
                                        prefillStart: gap.gapStart,
                                        prefillEnd: gap.gapEnd,
                                        selectID: item.id
                                    )
                                }
                            }
                        }

                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: selectedTimelineID) { _, newID in
                scrollBookingsList(to: newID, proxy: proxy)
            }
            .onAppear {
                scrollBookingsList(to: selectedTimelineID, proxy: proxy)
            }
        }
    }

    private func scrollBookingsList(to timelineID: String?, proxy: ScrollViewProxy) {
        guard let timelineID else { return }
        // LazyVStack: Zielzeile ggf. erst nach Layout-Pass vorhanden.
        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(timelineID, anchor: .center)
            }
        }
    }

    private func timelineItems(gaps: [ComputedGap], bookings: [SDBooking]) -> [TripTimelineItem] {
        TripTimelineItem.sorted(bookings: bookings, gaps: gaps)
    }

    private func gapPresentation(for gap: ComputedGap) -> GapPresentation {
        GapPresentation.resolve(computed: gap, saved: savedGapsByKey[gap.identityKey])
    }

    @ViewBuilder
    private var tripOverviewSection: some View {
        // Kompakte Einzeiler — kein LabeledContent/NSView (das blähte die Übersicht auf).
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                overviewFact(label: "Zeitraum", value: dateRange)
                overviewFact(label: "Preis", value: tripTotalPriceText)
                if let destination = trip.destination, !destination.isEmpty {
                    overviewFact(label: "Ziel", value: destination)
                }
                Spacer(minLength: 0)
            }
            if let notes = trip.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func overviewFact(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .textSelection(.enabled)
                .lineLimit(1)
        }
    }

    private var dateRange: String {
        let start = trip.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = trip.endDate.formatted(date: .abbreviated, time: .omitted)
        return "\(start) – \(end)"
    }

    private func openBookingsCandidates() -> [SDBooking] {
        allBookings.filter { OpenBookingMatching.isCandidate($0, for: trip) }
    }
}

private enum TimelineRowDisplayMode {
    case summary
    case details
}

private struct TimelineRowLabel: View {
    let item: TripTimelineItem
    let overlapCountsByBookingID: [UUID: Int]
    let gapPresentation: (ComputedGap) -> GapPresentation
    let onEditGap: (GapEditorPayload) -> Void

    var body: some View {
        switch item {
        case .booking(let booking):
            let overlapCount = overlapCountsByBookingID[booking.id] ?? 0
            BookingRow(
                booking: booking,
                displayMode: .summary,
                isOverlapping: overlapCount > 0,
                overlapCount: overlapCount,
                onSelect: nil
            )

        case .gap(let gap):
            let presentation = gapPresentation(gap)
            GapRow(
                gap: gap,
                displayMode: .summary,
                displayTitle: presentation.displayTitle,
                effectiveKind: presentation.effectiveKind,
                priceText: presentation.priceText,
                onEdit: { onEditGap(presentation.editorPayload(for: gap)) },
                onSelect: nil
            )
        }
    }
}

private struct ContentHeightReader: View {
    var onChange: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear { onChange(geometry.size.height) }
                .onChange(of: geometry.size.height) { _, height in
                    onChange(height)
                }
        }
    }
}

private struct BookingDetailPanel: View {
    let selectedTimelineItem: TripTimelineItem?
    let trip: SDTrip
    let overlapCountsByBookingID: [UUID: Int]
    @Binding var bookingEditorSession: BookingEditorSession?
    @Binding var selectedTimelineID: String?
    let onEditGap: (GapEditorPayload) -> Void
    let gapPresentation: (ComputedGap) -> GapPresentation
    let onRequestManualDeleteBooking: (UUID) -> Void
    let onRequestRemoveFromTrip: (UUID) -> Void
    var onContentHeightChange: ((CGFloat) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var bookingEditorDraft: BookingEditorDraft?

    private var selectedBooking: SDBooking? {
        guard case .booking(let booking) = selectedTimelineItem else { return nil }
        return booking
    }

    private var selectedBookingID: UUID? { selectedBooking?.id }

    private var isEditing: Bool { bookingEditorSession != nil }

    private var bookingStatusBarHeight: CGFloat { 32 }

    var body: some View {
        Group {
            if isEditing, let draftBinding = draftBinding {
                BookingEditorForm(
                    title: editorTitle,
                    showsSyncOverwriteHint: showsSyncOverwriteHint,
                    draft: draftBinding,
                    providerReadOnly: providerReadOnly,
                    onCancel: { clearEditor() },
                    onSave: { try saveEditor() }
                )
            } else {
                ZStack(alignment: .bottom) {
                    detailScrollContent
                        .padding(.bottom, bookingStatusBarHeight)

                    if let synced = selectedBooking?.lastSyncedAt {
                        bookingStatusBar(synced: synced)
                            .frame(height: bookingStatusBarHeight)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { syncDraftFromSession(resetDraft: false) }
        .onChange(of: bookingEditorSession) { _, _ in
            syncDraftFromSession(resetDraft: true)
        }
        .onChange(of: selectedBookingID) { _, newID in
            guard case .edit(let editingID) = bookingEditorSession else { return }
            guard newID != editingID else { return }
            clearEditor()
        }
        .onChange(of: trip.id) { _, _ in
            clearEditor()
        }
    }

    private func syncDraftFromSession(resetDraft: Bool) {
        switch bookingEditorSession {
        case .create(let prefillStart, let prefillEnd):
            guard resetDraft || bookingEditorDraft == nil else { return }
            bookingEditorDraft = BookingEditorDraft.createDefault(
                tripStartDate: trip.startDate,
                prefillStart: prefillStart,
                prefillEnd: prefillEnd
            )
        case .edit(let bookingID):
            guard resetDraft || bookingEditorDraft == nil else { return }
            if let booking = selectedBooking, booking.id == bookingID {
                bookingEditorDraft = BookingEditorDraft.fromExisting(booking)
            } else {
                bookingEditorDraft = nil
            }
        case nil:
            bookingEditorDraft = nil
        }
    }

    private var editorTitle: String {
        switch bookingEditorSession {
        case .create(_, _): return "Buchung hinzufügen"
        case .edit: return "Buchung bearbeiten"
        case nil: return "Buchung"
        }
    }

    private var showsSyncOverwriteHint: Bool {
        guard case .edit = bookingEditorSession,
              let booking = selectedBooking else { return false }
        return booking.provider != .manual
    }

    private var providerReadOnly: Bool {
        switch bookingEditorSession {
        case .edit: return true
        default: return false
        }
    }

    private var draftBinding: Binding<BookingEditorDraft>? {
        guard bookingEditorDraft != nil else { return nil }
        return Binding(
            get: { bookingEditorDraft! },
            set: { bookingEditorDraft = $0 }
        )
    }

    private var detailScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Divider()

                if let selectedTimelineItem {
                    Group {
                        switch selectedTimelineItem {
                        case .booking(let booking):
                            BookingDetailContent(
                                booking: booking,
                                isOverlapping: (overlapCountsByBookingID[booking.id] ?? 0) > 0,
                                overlapCount: overlapCountsByBookingID[booking.id] ?? 0,
                                onEditBooking: { bookingEditorSession = .edit(bookingID: booking.id) },
                                onRequestManualDeleteBooking: onRequestManualDeleteBooking,
                                onRequestRemoveFromTrip: onRequestRemoveFromTrip
                            )
                        case .gap(let gap):
                            let presentation = gapPresentation(gap)

                            GapRow(
                                gap: gap,
                                displayMode: .details,
                                displayTitle: presentation.displayTitle,
                                effectiveKind: presentation.effectiveKind,
                                priceText: presentation.priceText,
                                onEdit: {
                                    onEditGap(presentation.editorPayload(for: gap))
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Buchung in der Liste auswählen, um Details anzuzeigen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .background(.ultraThinMaterial)
            .background {
                ContentHeightReader { height in
                    onContentHeightChange?(height)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func clearEditor() {
        bookingEditorSession = nil
        bookingEditorDraft = nil
    }

    private func saveEditor() throws {
        guard let draft = bookingEditorDraft else { return }
        switch bookingEditorSession {
        case .create(_, _):
            let newID = try BookingEditorDraft.createBooking(
                from: draft,
                trip: trip,
                in: modelContext
            )
            selectedTimelineID = newID.uuidString
            clearEditor()
        case .edit:
            guard let booking = selectedBooking else { return }
            try draft.apply(to: booking, in: modelContext)
            clearEditor()
        case nil:
            break
        }
    }

    private func bookingStatusBar(synced: Date) -> some View {
        HStack(spacing: 8) {
            Text("Zuletzt synchronisiert")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(synced.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .background(.bar)
    }
}

/// Vollständige Buchungsdetails für das untere Panel (alle persistierten Felder).
private struct BookingDetailContent: View {
    let booking: SDBooking
    let isOverlapping: Bool
    let overlapCount: Int
    let onEditBooking: (() -> Void)?
    let onRequestManualDeleteBooking: (UUID) -> Void
    let onRequestRemoveFromTrip: (UUID) -> Void

    private var priceText: String {
        let details = booking.rateDetails
        guard let amount = details?.totalPriceAmount else { return "k.A." }
        return Formatting.formatCurrencyAmount(amount, currencyCode: details?.totalPriceCurrency)
    }

    private var hotelTimeZone: TimeZone { booking.resolvedHotelTimeZone }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.title ?? booking.bookingType.rawValue.capitalized)
                        .font(.headline)
                        .textSelection(.enabled)
                    if isOverlapping {
                        Text(overlapCount > 0 ? "Überschneidung (+\(overlapCount))" : "Überschneidung")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    ProviderLogo(providerID: booking.provider)
                    Text(booking.bookingType.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(priceText)
                        .font(.subheadline.weight(.semibold))
                }
            }

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160), spacing: 8, alignment: .leading),
            ], alignment: .leading, spacing: 6) {
                ForEach(BookingScheduleFields.make(booking: booking)) { field in
                    detailRow(field.label, field.value)
                }
            }

            if let rate = booking.rateDetails {
                Divider()
                Text("Preis / Tarif")
                    .font(.subheadline.weight(.semibold))
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 160), spacing: 8, alignment: .leading),
                ], alignment: .leading, spacing: 6) {
                    ForEach(BookingRateFields.make(rate: rate, booking: booking)) { field in
                        detailRow(field.label, field.value)
                    }
                }

                if !rate.resolvedRoomItems.isEmpty {
                    Divider()
                    Text("Zimmer / Positionen")
                        .font(.subheadline.weight(.semibold))
                    BookingRoomItemsView(rate: rate)
                }
            }

            if !booking.resolvedCancellationDeadlines.isEmpty {
                Divider()
                Text("Stornierung")
                    .font(.subheadline.weight(.semibold))
                BookingCancellationDeadlinesView(booking: booking, hotelTimeZone: hotelTimeZone)
            }

            if !booking.resolvedGuestHints.isEmpty {
                Divider()
                Text(GuestHintCategory.preTravelImportant.displayTitle)
                    .font(.subheadline.weight(.semibold))
                BookingGuestHintsView(booking: booking)
            }

            if let url = booking.browserURL {
                Divider()
                Link("Buchung im Browser öffnen", destination: url)
                    .font(.caption)
            }

            if let onEditBooking {
                Button("Bearbeiten") {
                    onEditBooking()
                }
                .buttonStyle(.link)
                .padding(.top, 4)
                .help("Diese Buchung bearbeiten")
            }

            if ProviderID(rawValue: booking.providerRaw) == .manual {
                Button(role: .destructive) {
                    onRequestManualDeleteBooking(booking.id)
                } label: {
                    Text("Löschen…")
                }
                .buttonStyle(.link)
                .padding(.top, 4)
                .help("Diese manuelle Buchung unwiderruflich löschen")
            }

            Button(role: .destructive) {
                onRequestRemoveFromTrip(booking.id)
            } label: {
                Text("Von Reise entfernen…")
            }
            .buttonStyle(.link)
            .padding(.top, 4)
            .help("Diese Buchung aus der Reise lösen und unter „Offene Buchungen“ anzeigen")
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BookingRow: View {
    let booking: SDBooking
    let displayMode: TimelineRowDisplayMode
    let isOverlapping: Bool
    let overlapCount: Int
    var onSelect: (() -> Void)? = nil

    private var bookingPriceText: String {
        let details = booking.rateDetails
        guard let amount = details?.totalPriceAmount else { return "k.A." }
        return Formatting.formatCurrencyAmount(amount, currencyCode: details?.totalPriceCurrency)
    }

    private func bookingTypeTitle(_ booking: SDBooking) -> String {
        booking.bookingType.rawValue.capitalized
    }

    private var hotelTimeZone: TimeZone { booking.resolvedHotelTimeZone }

    private func cancellationCopyText(
        futureDeadlinesForDisplay: [SDCancellationDeadline],
        hasFutureFreeCancellation: Bool
    ) -> String {
        var lines: [String] = []

        // Nur eine Lock-Zeile, nicht mehrfach.
        if !hasFutureFreeCancellation {
            lines.append("Fix (nicht mehr kostenlos stornierbar)")
        }

        for deadline in futureDeadlinesForDisplay {
            let tz = timeZone(forDeadline: deadline)
            if deadline.isFreeCancellation {
                lines.append(
                    "Kostenlos stornierbar bis \(Formatting.formatOrtszeit(deadline.deadlineAt, dateFormat: "d.M. HH:mm", timeZone: tz))"
                )
            } else {
                let paidText = (deadline.policyText?.isEmpty == false)
                    ? deadline.policyText!
                    : "Kostenpflichtig stornierbar bis \(Formatting.formatOrtszeit(deadline.deadlineAt, dateFormat: "d.M. HH:mm", timeZone: tz))"
                lines.append(paidText)
            }
        }

        return lines.joined(separator: "\n")
    }

    private func computeFutureDeadlinesForDisplay(now: Date = Date()) -> [SDCancellationDeadline] {
        let service = CancellationDeadlineDisplayService()
        let domainDeadlines = booking.resolvedCancellationDeadlines.map(DomainMapper.deadline(from:))
        let filteredDomainDeadlines = service.deadlinesForDisplay(domainDeadlines, now: now)
        let deadlinesByID = Dictionary(uniqueKeysWithValues: booking.resolvedCancellationDeadlines.map { ($0.id, $0) })
        // Preserve the ascending order returned by the domain/service layer.
        return filteredDomainDeadlines.compactMap { deadlinesByID[$0.id] }
    }

    private func bookingTimeCopyText() -> String {
        switch booking.bookingType {
        case .hotel:
            let checkInDate = HotelStayDate.format(
                booking.startAt,
                dateFormat: "d.M.",
                legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
            )
            let checkOutDate = HotelStayDate.format(
                booking.endAt,
                dateFormat: "d.M.",
                legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
            )
            let checkInTime = booking.hotelCheckInMinutes.map(Formatting.minutesToHHmm) ?? "—"
            let checkOutTime = booking.hotelCheckOutMinutes.map(Formatting.minutesToHHmm) ?? "—"

            return "Check-in: \(checkInDate) ab \(checkInTime) (\(hotelLocationLabel))\nCheck-out: \(checkOutDate) bis \(checkOutTime) (\(hotelLocationLabel))"

        case .flight, .ferry:
            let departureOffsetSeconds = booking.flightDepartureOffsetSeconds
            let arrivalOffsetSeconds = booking.flightArrivalOffsetSeconds

            let departureTZ = (departureOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) }) ?? .current
            let arrivalTZ = (arrivalOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) }) ?? .current

            let tzHint: String = {
                if departureOffsetSeconds == nil || arrivalOffsetSeconds == nil { return " (Zeitzone noch nicht ermittelt)" }
                return ""
            }()

            let departure = Formatting.formatOrtszeit(
                booking.startAt,
                dateFormat: "d.M. HH:mm",
                timeZone: departureTZ
            )
            let arrival = Formatting.formatOrtszeit(
                booking.endAt,
                dateFormat: "d.M. HH:mm",
                timeZone: arrivalTZ
            )

            return "Abflug: \(departure) (\(flightOriginLabel))\(tzHint)\nAnkunft: \(arrival) (\(flightDestinationLabel))"

        case .activity, .other:
            return "\(booking.startAt.formatted(date: .abbreviated, time: .shortened)) – \(booking.endAt.formatted(date: .abbreviated, time: .shortened))"
        }
    }

    /// Start-/Enddatum für die Listenzeile (ohne Check-in/Check-out-Uhrzeiten).
    private func bookingSummaryDateRangeText() -> String {
        switch booking.bookingType {
        case .hotel:
            let start = HotelStayDate.format(
                booking.startAt,
                dateFormat: "d.M.",
                legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
            )
            let end = HotelStayDate.format(
                booking.endAt,
                dateFormat: "d.M.",
                legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
            )
            return "\(start) – \(end) (\(hotelLocationLabel))"
        case .flight, .ferry:
            return bookingTimeCopyText()
        case .activity, .other:
            return "\(booking.startAt.formatted(date: .abbreviated, time: .omitted)) – \(booking.endAt.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    private func bookingFullCopyText(now: Date) -> String {
        var parts: [String] = []

        parts.append(booking.title ?? bookingTypeTitle(booking))
        parts.append(bookingTypeTitle(booking))
        parts.append("Preis: \(bookingPriceText)")

        if isOverlapping {
            parts.append(overlapCount > 0 ? "Überschneidung (+\(overlapCount))" : "Überschneidung")
        }

        parts.append(bookingTimeCopyText())

        // Für Copy müssen auch Fälle abgedeckt werden, in denen es Stornofristen gibt,
        // aber keine zukünftigen Freistornierungen mehr (UI zeigt dann "Fix ...").
        if !booking.resolvedCancellationDeadlines.isEmpty {
            let futureDeadlinesForDisplay = computeFutureDeadlinesForDisplay(now: now)
            let hasFutureFreeCancellation = futureDeadlinesForDisplay.contains { $0.isFreeCancellation }
            parts.append(cancellationCopyText(
                futureDeadlinesForDisplay: futureDeadlinesForDisplay,
                hasFutureFreeCancellation: hasFutureFreeCancellation
            ))
        }

        return parts.joined(separator: "\n")
    }

    private func bookingAttributedDisplayText(now: Date) -> AttributedString {
        let ns = NSMutableAttributedString()
        appendHeaderAttributed(to: ns)
        appendTimeBlockAttributed(to: ns)
        appendCancellationBlockAttributed(to: ns, now: now)
        trimFinalNewline(from: ns)
        return AttributedString(ns)
    }

    private func appendHeaderAttributed(to ns: NSMutableAttributedString) {
        let headlineFont = NSFont.preferredFont(forTextStyle: .headline)
        let caption2Font = NSFont.preferredFont(forTextStyle: .caption2)

        let secondary = NSColor.secondaryLabelColor
        let orange = NSColor.systemOrange

        let title = booking.title ?? booking.bookingType.rawValue.capitalized
        ns.append(NSAttributedString(string: title, attributes: [
            .font: headlineFont,
            .foregroundColor: secondary
        ]))

        if isOverlapping {
            let overlapText = overlapCount > 0 ? "Überschneidung (+\(overlapCount))" : "Überschneidung"
            ns.append(NSAttributedString(string: "  \(overlapText)", attributes: [
                .font: caption2Font,
                .foregroundColor: orange
            ]))
        }

        ns.append(NSAttributedString(string: "\n"))
    }

    private func appendTimeBlockAttributed(to ns: NSMutableAttributedString) {
        let subheadlineFont = NSFont.preferredFont(forTextStyle: .subheadline)
        let secondary = NSColor.secondaryLabelColor

        let timeText = bookingTimeCopyText()
        let lines = timeText.components(separatedBy: "\n")
        for line in lines {
            ns.append(NSAttributedString(string: line, attributes: [
                .font: subheadlineFont,
                .foregroundColor: secondary
            ]))
            ns.append(NSAttributedString(string: "\n"))
        }
    }

    private func appendCancellationBlockAttributed(to ns: NSMutableAttributedString, now: Date) {
        guard displayMode == .details, !booking.resolvedCancellationDeadlines.isEmpty else { return }

        let captionFont = NSFont.preferredFont(forTextStyle: .caption1)
        let secondary = NSColor.secondaryLabelColor
        let orange = NSColor.systemOrange
        let green = NSColor.systemGreen
        let red = NSColor.systemRed

        let futureDeadlinesForDisplay = computeFutureDeadlinesForDisplay(now: now)
        if futureDeadlinesForDisplay.isEmpty {
            appendIconLine(
                to: ns,
                systemName: "lock.fill",
                text: "Fix (nicht mehr kostenlos stornierbar)",
                font: captionFont,
                color: secondary
            )
            return
        }

        let hasFutureFreeCancellation = futureDeadlinesForDisplay.contains { $0.isFreeCancellation }
        let urgencyService = CancellationUrgencyService()

        if !hasFutureFreeCancellation {
            appendIconLine(
                to: ns,
                systemName: "lock.fill",
                text: "Fix (nicht mehr kostenlos stornierbar)",
                font: captionFont,
                color: secondary
            )
        }

        for deadline in futureDeadlinesForDisplay {
            appendCancellationDeadlineLine(
                to: ns,
                deadline: deadline,
                now: now,
                urgencyService: urgencyService,
                font: captionFont,
                secondary: secondary,
                orange: orange,
                green: green,
                red: red
            )
        }
    }

    private func appendCancellationDeadlineLine(
        to ns: NSMutableAttributedString,
        deadline: SDCancellationDeadline,
        now: Date,
        urgencyService: CancellationUrgencyService,
        font: NSFont,
        secondary: NSColor,
        orange: NSColor,
        green: NSColor,
        red: NSColor
    ) {
        if deadline.isFreeCancellation {
            let urgency = urgencyService.urgency(for: DomainMapper.deadline(from: deadline), now: now)
            let color: NSColor = {
                switch urgency {
                case .ok: return green
                case .warning: return orange
                case .critical: return red
                case .fix: return secondary
                }
            }()

            appendIconLine(
                to: ns,
                systemName: "checkmark.circle.fill",
                text: "Kostenlos stornierbar bis \(Formatting.formatOrtszeit(deadline.deadlineAt, dateFormat: "d.M. HH:mm", timeZone: timeZone(forDeadline: deadline)))",
                font: font,
                color: color
            )
        } else {
            let paidText = (deadline.policyText?.isEmpty == false)
                ? deadline.policyText!
                : "Kostenpflichtig stornierbar bis \(Formatting.formatOrtszeit(deadline.deadlineAt, dateFormat: "d.M. HH:mm", timeZone: timeZone(forDeadline: deadline)))"

            appendIconLine(
                to: ns,
                systemName: "tag.fill",
                text: paidText,
                font: font,
                color: secondary
            )
        }
    }

    private func appendIconLine(
        to ns: NSMutableAttributedString,
        systemName: String,
        text: String,
        font: NSFont,
        color: NSColor,
        iconSize: CGFloat = 12
    ) {
        appendIcon(
            to: ns,
            systemName: systemName,
            color: color,
            size: iconSize
        )

        ns.append(NSAttributedString(string: " ", attributes: [
            .font: font,
            .foregroundColor: color
        ]))
        ns.append(NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color
        ]))
        ns.append(NSAttributedString(string: "\n"))
    }

    private func appendIcon(
        to ns: NSMutableAttributedString,
        systemName: String,
        color: NSColor,
        size: CGFloat
    ) {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        guard let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }

        // Template-Rendering, damit das Symbol durch Textfarbe/Attributes mitgefärbt werden kann.
        image.isTemplate = true

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: -1, width: size, height: size)

        let iconString = NSAttributedString(attachment: attachment)
        ns.append(iconString)

        if iconString.length > 0 {
            let range = NSRange(location: ns.length - iconString.length, length: iconString.length)
            ns.addAttributes([.foregroundColor: color], range: range)
        }
    }

    private func trimFinalNewline(from ns: NSMutableAttributedString) {
        while ns.string.hasSuffix("\n") && ns.length > 0 {
            ns.deleteCharacters(in: NSRange(location: ns.length - 1, length: 1))
        }
    }

    /// Storno: Deadline-Offset aus Provider-ISO (Opodo `-00:00` → 1.8. 22:00, nicht CEST 2.8. 00:00).
    private func timeZone(forDeadline deadline: SDCancellationDeadline) -> TimeZone {
        if let offsetSeconds = deadline.hotelOffsetSeconds {
            return TimeZone(secondsFromGMT: offsetSeconds) ?? hotelTimeZone
        }
        return hotelTimeZone
    }

    private var hotelLocationLabel: String {
        let label = booking.locationTo ?? booking.locationFrom ?? ""
        return label.isEmpty ? "Ziel" : label
    }

    private var flightOriginLabel: String {
        let label = booking.locationFrom ?? ""
        return label.isEmpty ? "Abflugort" : label
    }

    private var flightDestinationLabel: String {
        let label = booking.locationTo ?? ""
        return label.isEmpty ? "Ankunftsort" : label
    }

    var body: some View {
        // Summary: reines SwiftUI (kein NSTextView/onTapGesture — sonst verzögerte Listen-Klicks).
        Group {
            if displayMode == .summary {
                bookingSummaryBody
            } else {
                bookingDetailsBody
            }
        }
        .padding(.vertical, 2)
    }

    private var bookingSummaryBody: some View {
        let now = Date()
        let stornoLines = BookingStornoSummary.lines(for: booking, now: now)

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(booking.title ?? bookingTypeTitle(booking))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if isOverlapping {
                        Text(overlapCount > 0 ? "Überschneidung (+\(overlapCount))" : "Überschneidung")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Text(bookingSummaryDateRangeText())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if !stornoLines.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(stornoLines) { line in
                            Label {
                                Text(line.text)
                                    .font(.caption)
                                    .foregroundStyle(line.color)
                                    .lineLimit(2)
                            } icon: {
                                Image(systemName: line.systemImage)
                                    .font(.caption)
                                    .foregroundStyle(line.color)
                            }
                            .labelStyle(.titleAndIcon)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                ProviderLogo(providerID: booking.provider)
                Text(bookingTypeTitle(booking))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(bookingPriceText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var bookingDetailsBody: some View {
        let now = Date()
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                SelectableBookingTextView(
                    attributedString: bookingAttributedDisplayText(now: now),
                    copyText: bookingFullCopyText(now: now)
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    ProviderLogo(providerID: booking.provider)
                    Text(bookingTypeTitle(booking))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(bookingPriceText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

        }
    }
}

private struct GapRow: View {
    let gap: ComputedGap
    let displayMode: TimelineRowDisplayMode
    let displayTitle: String
    let effectiveKind: GapKind
    let priceText: String?
    let onEdit: () -> Void
    var onSelect: (() -> Void)? = nil

    @Environment(\.providerRegistry) private var providerRegistry

    private var hotelTimeZone: TimeZone {
        HotelTimeZone.resolve(
            fromOffsetSeconds: gap.fromBooking.hotelOffsetSeconds,
            toOffsetSeconds: gap.toBooking.hotelOffsetSeconds
        )
    }

    private var linkSuggestions: (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        providerRegistry?.gapDeepLinkSuggestions(for: gap, kind: effectiveKind) ?? ([], [])
    }

    var body: some View {
        Group {
            if displayMode == .summary {
                gapSummaryBody
            } else {
                gapDetailsBody
            }
        }
        .padding(.vertical, 4)
    }

    private var gapSummaryBody: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text("\(Formatting.formatOrtszeit(gap.gapStart, dateFormat: "d.M.", timeZone: hotelTimeZone)) – \(Formatting.formatOrtszeit(gap.gapEnd, dateFormat: "d.M.", timeZone: hotelTimeZone))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(effectiveKind.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var gapDetailsBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text("\(Formatting.formatOrtszeit(gap.gapStart, dateFormat: "d.M.", timeZone: hotelTimeZone)) – \(Formatting.formatOrtszeit(gap.gapEnd, dateFormat: "d.M.", timeZone: hotelTimeZone))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button("Bearbeiten") {
                    onEdit()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Typ: \(effectiveKind.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let priceText {
                Text("Preis: \(priceText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                GapDeepLinkButtons(
                    links: linkSuggestions.links,
                    gapKind: effectiveKind
                ) { url in
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if let issuesMessage = ProviderDeepLinks.issuesMessage(linkSuggestions.issues) {
                Text(issuesMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

