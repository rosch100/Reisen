import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData
import ReisenSharedUI
import ReisenProviders
import ReisenAppCore
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
    @Environment(\.providerSessionHub) private var sessionHub
    @Environment(\.openURL) private var openURL
    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]
    @State private var cancelRequest: BookingPortalCancelRequest?
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
        guard !amounts.isEmpty else { return L10n.string(.commonNotAvailable) }

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
        BookingDayOverlap.countsByID(sdBookings: allBookings)
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
        let oldTripID = booking.trip?.id
        booking.trip = nil
        do {
            try modelContext.save()
            if let oldTripID {
                try AutoGapReconcileTrigger.run(tripIDs: [oldTripID], in: modelContext)
                try modelContext.save()
            }
        } catch {
            persistErrorMessage = error.localizedDescription
        }

        let removedID = booking.id.uuidString
        if selectedTimelineID == removedID {
            selectedTimelineID = (removedID == fallbackTimelineID) ? nil : fallbackTimelineID
        }

        if case .edit(let editingID, _) = bookingEditorSession,
           editingID == booking.id {
            bookingEditorSession = nil
        }
    }

    private func requestDeleteBooking(_ booking: SDBooking) {
        selectTimelineID(booking.id.uuidString)
        pendingDeleteBookingID = booking.id
        showDeleteConfirmation = true
    }

    private func requestRemoveBookingFromTrip(_ booking: SDBooking) {
        selectTimelineID(booking.id.uuidString)
        pendingRemoveFromTripBookingID = booking.id
        showRemoveFromTripConfirmation = true
    }

    @State private var showAssignBookings = false
    @State private var assignPreselectedBookingIDs: Set<UUID> = []
    @State private var pendingDeleteBookingID: UUID?
    @State private var showDeleteConfirmation = false
    @State private var pendingRemoveFromTripBookingID: UUID?
    @State private var showRemoveFromTripConfirmation = false
    @State private var persistErrorMessage: String?

    private var pendingDeleteBooking: SDBooking? {
        guard let pendingDeleteBookingID else { return nil }
        return trip.resolvedBookings.first(where: { $0.id == pendingDeleteBookingID })
    }

    private func confirmDeleteBooking() {
        guard let bookingIDToDelete = pendingDeleteBookingID,
              let bookingToDelete = trip.resolvedBookings.first(where: { $0.id == bookingIDToDelete }) else {
            pendingDeleteBookingID = nil
            return
        }
        do {
            try BookingDeletion.perform(booking: bookingToDelete, in: modelContext)
        } catch {
            persistErrorMessage = error.localizedDescription
            pendingDeleteBookingID = nil
            return
        }

        let newSelection = trip.timelineBookings().first?.id.uuidString

        if selectedTimelineID == bookingIDToDelete.uuidString {
            selectedTimelineID = newSelection
        }

        if case .edit(let editingID, _) = bookingEditorSession,
           editingID == bookingIDToDelete {
            bookingEditorSession = nil
        }

        pendingDeleteBookingID = nil
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

                Text(L10n.string(.tripBookings))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                    .fixedSize(horizontal: false, vertical: true)

                if timelineItems.isEmpty {
                    ContentUnavailableView {
                        Label(L10n.string(.tripNoBookings), systemImage: "calendar.badge.exclamationmark")
                    } description: {
                        Text(L10n.string(.tripNoFutureBookings))
                    } actions: {
                        Button(L10n.string(.actionAddBooking)) {
                            startCreateBooking(prefillStart: nil, prefillEnd: nil, selectID: nil)
                        }
                        Button(L10n.string(.actionAssignBookings)) {
                            showAssignBookings = true
                        }
                        .disabled(openBookingsCandidates().isEmpty)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    bookingsList(timelineItems: timelineItems, fallbackTimelineID: firstBookingTimelineID)
                }
            }
            .accessibilityIdentifier(UITestingIdentifiers.detail)
            .navigationTitle(trip.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.string(.actionAssignBookings)) {
                        showAssignBookings = true
                    }
                    .disabled(openBookingsCandidates().isEmpty)
                    .help(openBookingsCandidates().isEmpty
                        ? L10n.string(.tripNoOpenInRange)
                        : L10n.string(.tripAssignOpenHelp))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.string(.actionAddBooking)) {
                        startCreateBooking(prefillStart: nil, prefillEnd: nil, selectID: nil)
                    }
                    .help(L10n.string(.tripAddBookingHelp))
                    .accessibilityIdentifier(UITestingIdentifiers.addBooking)
                }
            }
            .sheet(isPresented: $showAssignBookings) {
                AssignBookingsSheet(
                    trip: trip,
                    candidates: openBookingsCandidates(),
                    initiallySelectedBookingIDs: assignPreselectedBookingIDs
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
            .onReceive(NotificationCenter.default.publisher(for: .reisenAssignBookings)) { note in
                let candidates = openBookingsCandidates()
                guard !candidates.isEmpty else { return }
                if let bookingID = note.object as? UUID,
                   candidates.contains(where: { $0.id == bookingID }) {
                    assignPreselectedBookingIDs = [bookingID]
                } else {
                    assignPreselectedBookingIDs = []
                }
                showAssignBookings = true
            }
            .onChange(of: showAssignBookings) { _, isPresented in
                if !isPresented {
                    assignPreselectedBookingIDs = []
                }
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
            .onReceive(NotificationCenter.default.publisher(for: .reisenRequestDeleteBooking)) { note in
                guard let bookingID = note.object as? UUID,
                      let booking = trip.resolvedBookings.first(where: { $0.id == bookingID }) else { return }
                requestDeleteBooking(booking)
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
                    onRequestDeleteBooking: { bookingID in
                        pendingDeleteBookingID = bookingID
                        showDeleteConfirmation = true
                    },
                    onRequestRemoveFromTrip: { bookingID in
                        guard let booking = trip.resolvedBookings.first(where: { $0.id == bookingID }) else { return }
                        requestRemoveBookingFromTrip(booking)
                    },
                    hasSessionWebView: { booking in
                        sessionHub.hasSessionWebView(for: booking)
                    },
                    onPresentCancel: { booking, presentation, url in
                        BookingPortalCancelRequest.route(
                            presentation,
                            url: url,
                            booking: booking,
                            openURL: { openURL($0) },
                            setCancelRequest: { cancelRequest = $0 }
                        )
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
            showDeleteConfirmation: $showDeleteConfirmation,
            showRemoveFromTripConfirmation: $showRemoveFromTripConfirmation,
            bookingTitle: pendingDeleteBooking?.presentationTitle ?? L10n.string(.editorBooking),
            showsSyncRestoreWarning: pendingDeleteBooking.map {
                ProviderID.syncProviderIDs.contains($0.provider)
            } ?? false,
            onConfirmDelete: confirmDeleteBooking,
            onConfirmRemove: confirmRemoveBookingFromTrip,
            onCancelDelete: { pendingDeleteBookingID = nil },
            onCancelRemove: { pendingRemoveFromTripBookingID = nil }
        )
        .persistFailureAlert(message: $persistErrorMessage)
        .bookingPortalCancelSheet($cancelRequest)
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
                        .accessibilityIdentifier(timelineItemIdentifier(item))
                        .contextMenu {
                            switch item {
                            case .booking(let booking):
                                Button(L10n.string(.commonEdit)) { editBooking(booking) }
                                Button(L10n.string(.actionAddBooking)) {
                                    startCreateBooking(
                                        prefillStart: nil,
                                        prefillEnd: nil,
                                        selectID: booking.id.uuidString
                                    )
                                }
                                BookingCopyConfirmationMenuItems(booking: booking)
                                if let url = booking.browserURL {
                                    BookingPortalOpenButton(browserURL: url)
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
                                Button(role: .destructive) {
                                    requestRemoveBookingFromTrip(booking)
                                } label: {
                                    Text(L10n.string(.actionRemoveFromTrip))
                                }

                                Button(role: .destructive) { requestDeleteBooking(booking) } label: {
                                    Text(L10n.string(.actionDeleteEllipsis))
                                }

                            case .gap(let gap):
                                let editPayload = gapPresentation(for: gap).editorPayload(for: gap)

                                Button(L10n.string(.actionEditGap)) {
                                    selectTimelineID(item.id)
                                    gapEditorPayload = editPayload
                                }
                                Button(L10n.string(.actionAddBooking)) {
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

    private func timelineItemIdentifier(_ item: TripTimelineItem) -> String {
        if case .booking(let booking) = item {
            return UITestingIdentifiers.bookingRow(booking.id)
        }
        return "reisen.gap.\(item.id)"
    }

    private func gapPresentation(for gap: ComputedGap) -> GapPresentation {
        GapPresentation.resolve(computed: gap, saved: savedGapsByKey[gap.identityKey])
    }

    @ViewBuilder
    private var tripOverviewSection: some View {
        // Kompakte Einzeiler — kein LabeledContent/NSView (das blähte die Übersicht auf).
        let completeness = trip.completeness()
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                overviewFact(label: L10n.string(.tripPeriod), value: dateRange)
                overviewFact(label: L10n.string(.bookingDetailPrice), value: tripTotalPriceText)
                if let destination = trip.destination, !destination.isEmpty {
                    overviewFact(label: L10n.string(.tripDestination), value: destination)
                }
                if completeness.hasBookings {
                    overviewFact(
                        label: L10n.string(.tripCompletenessLabel),
                        value: L10n.tripCompletenessOverviewFactValue(completeness)
                    )
                    .help(L10n.string(.tripCompletenessHelp))
                }
                Spacer(minLength: 0)
            }
            if completeness.hasBookings {
                TripCompletenessMacDetailCaption(completeness: completeness)
            }
            if let notes = trip.notes, !notes.isEmpty {
                CopyableFieldValue(
                    value: notes,
                    kind: .standard,
                    textStyle: .caption,
                    foregroundStyle: .secondary,
                    lineLimit: 2
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func overviewFact(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            CopyableFieldValue(
                value: value,
                kind: .standard,
                textStyle: .subheadline,
                lineLimit: 1
            )
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
    let onRequestDeleteBooking: (UUID) -> Void
    let onRequestRemoveFromTrip: (UUID) -> Void
    var hasSessionWebView: (SDBooking) -> Bool
    var onPresentCancel: (SDBooking, BookingPortalCancelPresentation, URL) -> Void
    var onContentHeightChange: ((CGFloat) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var bookingEditorDraft: BookingEditorDraft?
    @State private var pendingPeriodExpand: TripPeriodExpandOnAssign.Proposal?
    @State private var showPeriodExpandConfirm = false
    @State private var persistErrorMessage: String?

    private var selectedBooking: SDBooking? {
        guard case .booking(let booking) = selectedTimelineItem else { return nil }
        return booking
    }

    private var selectedBookingID: UUID? { selectedBooking?.id }

    private var isEditing: Bool { bookingEditorSession != nil }

    private var bookingStatusBarHeight: CGFloat { BookingLastSyncedBar.barHeight }

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
                        BookingLastSyncedBar(synced: synced)
                            .frame(height: bookingStatusBarHeight)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier(UITestingIdentifiers.inspector)
        .onAppear { syncDraftFromSession(resetDraft: false) }
        .onChange(of: bookingEditorSession) { _, _ in
            syncDraftFromSession(resetDraft: true)
        }
        .onChange(of: selectedBookingID) { _, newID in
            guard case .edit(let editingID, _) = bookingEditorSession else { return }
            guard newID != editingID else { return }
            clearEditor()
        }
        .onChange(of: trip.id) { _, _ in
            clearEditor()
        }
        .alert(
            TripPeriodExpandPrompt.title,
            isPresented: $showPeriodExpandConfirm
        ) {
            Button(TripPeriodExpandPrompt.confirmAction) {
                confirmPeriodExpandAndCreate()
            }
            Button(TripPeriodExpandPrompt.declineAction, role: .cancel) {
                declinePeriodExpandAndCreateOpen()
            }
        } message: {
            if let pendingPeriodExpand {
                Text(TripPeriodExpandPrompt.message(for: pendingPeriodExpand))
            }
        }
        .persistFailureAlert(message: $persistErrorMessage)
    }

    private func syncDraftFromSession(resetDraft: Bool) {
        switch bookingEditorSession {
        case .create(let prefillStart, let prefillEnd, let prefilledDraft):
            guard resetDraft || bookingEditorDraft == nil else { return }
            bookingEditorDraft = prefilledDraft ?? BookingEditorDraft.createDefault(
                tripStartDate: trip.startDate,
                prefillStart: prefillStart,
                prefillEnd: prefillEnd
            )
        case .edit(let bookingID, let prefilledDraft):
            guard resetDraft || bookingEditorDraft == nil else { return }
            if let booking = selectedBooking, booking.id == bookingID {
                bookingEditorDraft = prefilledDraft ?? BookingEditorDraft.fromExisting(booking)
            } else {
                bookingEditorDraft = nil
            }
        case nil:
            bookingEditorDraft = nil
        }
    }

    private var editorTitle: String {
        switch bookingEditorSession {
        case .create: return L10n.string(.editorCreateTitle)
        case .edit: return L10n.string(.editorEditTitle)
        case nil: return L10n.string(.editorBooking)
        }
    }

    private var showsSyncOverwriteHint: Bool {
        guard case .edit = bookingEditorSession,
              let booking = selectedBooking else { return false }
        return ProviderID.syncProviderIDs.contains(booking.provider)
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
                                overlapCount: overlapCountsByBookingID[booking.id] ?? 0,
                                onEditBooking: { bookingEditorSession = .edit(bookingID: booking.id) },
                                onRequestDeleteBooking: onRequestDeleteBooking,
                                onRequestRemoveFromTrip: onRequestRemoveFromTrip,
                                hasSessionWebView: hasSessionWebView(booking),
                                onPresentCancel: { presentation, url in
                                    onPresentCancel(booking, presentation, url)
                                }
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
                    .id(selectedTimelineItem.id)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(L10n.string(.tripSelectBookingDetails))
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
        pendingPeriodExpand = nil
        showPeriodExpandConfirm = false
    }

    private func saveEditor() throws {
        guard let draft = bookingEditorDraft else { return }
        switch bookingEditorSession {
        case .create:
            if let proposal = TripPeriodExpandOnAssign.proposalIfNeeded(
                bookingStart: draft.startAt,
                bookingEnd: draft.endAt,
                tripStart: trip.startDate,
                tripEnd: trip.endDate
            ) {
                pendingPeriodExpand = proposal
                showPeriodExpandConfirm = true
                return
            }
            try createBookingAssigned(to: trip)
        case .edit:
            guard let booking = selectedBooking else { return }
            try draft.apply(to: booking, in: modelContext)
            clearEditor()
        case nil:
            break
        }
    }

    private func confirmPeriodExpandAndCreate() {
        guard let proposal = pendingPeriodExpand else { return }
        trip.startDate = proposal.start
        trip.endDate = proposal.end
        do {
            try createBookingAssigned(to: trip)
        } catch {
            persistErrorMessage = error.localizedDescription
        }
    }

    private func declinePeriodExpandAndCreateOpen() {
        do {
            try createBookingAssigned(to: nil)
        } catch {
            persistErrorMessage = error.localizedDescription
        }
    }

    private func createBookingAssigned(to trip: SDTrip?) throws {
        guard let draft = bookingEditorDraft else { return }
        let newID = try BookingEditorDraft.createBooking(
            from: draft,
            trip: trip,
            in: modelContext
        )
        selectedTimelineID = newID.uuidString
        clearEditor()
    }
}

private struct BookingRow: View {
    let booking: SDBooking
    let displayMode: TimelineRowDisplayMode
    let overlapCount: Int
    var onSelect: (() -> Void)? = nil

    private var bookingPriceText: String {
        let details = booking.rateDetails
        guard let amount = details?.totalPriceAmount else { return BookingDetailLabels.notAvailable }
        return Formatting.formatCurrencyAmount(amount, currencyCode: details?.totalPriceCurrency)
    }

    private var hotelTimeZone: TimeZone { booking.resolvedHotelTimeZone }

    private func cancellationCopyText(
        futureDeadlinesForDisplay: [SDCancellationDeadline],
        hasFutureFreeCancellation: Bool
    ) -> String {
        var lines: [String] = []

        // Nur eine Lock-Zeile, nicht mehrfach.
        if !hasFutureFreeCancellation {
            lines.append(L10n.string(.bookingCancellationLocked))
        }

        for deadline in futureDeadlinesForDisplay {
            let tz = timeZone(forDeadline: deadline)
            let formattedDeadline = Formatting.formatOrtszeit(
                deadline.deadlineAt,
                dateFormat: "d.M. HH:mm",
                timeZone: tz
            )
            if deadline.isFreeCancellation {
                lines.append(L10n.format(.bookingCancellationFreeUntil, formattedDeadline))
            } else {
                let paidText = (deadline.policyText?.isEmpty == false)
                    ? deadline.policyText!
                    : L10n.format(.bookingCancellationPaidUntil, formattedDeadline)
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

            return [
                L10n.format(.bookingTimelineHotelCheckIn, checkInDate, checkInTime, hotelLocationLabel),
                L10n.format(.bookingTimelineHotelCheckOut, checkOutDate, checkOutTime, hotelLocationLabel),
            ].joined(separator: "\n")

        case .flight, .ferry, .train:
            return transportPointToPointCopy()

        case .carRental:
            let pickup = Formatting.formatOrtszeit(
                booking.startAt,
                dateFormat: "d.M. HH:mm",
                timeZone: booking.resolvedHotelTimeZone
            )
            let dropoff = Formatting.formatOrtszeit(
                booking.endAt,
                dateFormat: "d.M. HH:mm",
                timeZone: booking.resolvedHotelTimeZone
            )
            return [
                L10n.format(.bookingTimelineCarPickup, pickup),
                L10n.format(.bookingTimelineCarDropoff, dropoff),
            ].joined(separator: "\n")

        case .activity, .other:
            return "\(booking.startAt.formatted(date: .abbreviated, time: .shortened)) – \(booking.endAt.formatted(date: .abbreviated, time: .shortened))"
        }
    }

    /// Flug/Fähre/Bahn: Ortszeit-Paar; Timezone-Pending nur für Flug.
    private func transportPointToPointCopy() -> String {
        let departureKey: L10nKey
        let arrivalKey: L10nKey
        switch booking.bookingType {
        case .flight:
            departureKey = .bookingTimelineFlightDeparture
            arrivalKey = .bookingTimelineFlightArrival
        case .ferry:
            departureKey = .bookingTimelineFerryDeparture
            arrivalKey = .bookingTimelineFerryArrival
        case .train:
            departureKey = .bookingTimelineTrainDeparture
            arrivalKey = .bookingTimelineTrainArrival
        case .hotel, .activity, .carRental, .other:
            preconditionFailure("transportPointToPointCopy nur für usesFlightLikeSchedule")
        }

        let departureOffset = booking.flightDepartureOffsetSeconds
        let arrivalOffset = booking.flightArrivalOffsetSeconds
        let departureTZ = departureOffset.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
        let arrivalTZ = arrivalOffset.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
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
        let departureLine: String
        if booking.bookingType == .flight {
            let tzHint = (departureOffset == nil || arrivalOffset == nil)
                ? L10n.string(.bookingTimelineTimezonePending)
                : ""
            departureLine = L10n.format(departureKey, departure, transportOriginLabel, tzHint)
        } else {
            departureLine = L10n.format(departureKey, departure, transportOriginLabel)
        }
        return [
            departureLine,
            L10n.format(arrivalKey, arrival, transportDestinationLabel),
        ].joined(separator: "\n")
    }

    /// Start-/Enddatum für die Listenzeile (ohne Check-in/Check-out-Uhrzeiten).
    private func bookingSummaryDateRangeText() -> String {
        if booking.bookingType == .hotel {
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
        }
        if booking.bookingType.usesFlightLikeSchedule {
            return bookingTimeCopyText()
        }
        return "\(booking.startAt.formatted(date: .abbreviated, time: .omitted)) – \(booking.endAt.formatted(date: .abbreviated, time: .omitted))"
    }

    private func bookingFullCopyText(now: Date) -> String {
        var parts: [String] = []

        parts.append(booking.presentationTitle)
        parts.append(booking.bookingType.displayLabel)
        parts.append(L10n.format(.bookingCopyPriceLine, bookingPriceText))

        if BookingOverlapCaption.isVisible(overlapCount: overlapCount) {
            parts.append(BookingOverlapCaption.labelText(extraCount: overlapCount))
        }
        if let elapsed = BookingElapsedText.string(for: booking, now: now) {
            parts.append(elapsed)
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
        appendHeaderAttributed(to: ns, now: now)
        appendTimeBlockAttributed(to: ns)
        appendCancellationBlockAttributed(to: ns, now: now)
        trimFinalNewline(from: ns)
        return AttributedString(ns)
    }

    private func appendHeaderAttributed(to ns: NSMutableAttributedString, now: Date) {
        let headlineFont = NSFont.preferredFont(forTextStyle: .headline)
        let caption2Font = NSFont.preferredFont(forTextStyle: .caption2)

        let secondary = NSColor.secondaryLabelColor
        let orange = NSColor.systemOrange

        let title = booking.presentationTitle
        ns.append(NSAttributedString(string: title, attributes: [
            .font: headlineFont,
            .foregroundColor: secondary
        ]))

        if BookingOverlapCaption.isVisible(overlapCount: overlapCount) {
            let overlapText = BookingOverlapCaption.labelText(extraCount: overlapCount)
            ns.append(NSAttributedString(string: "  \(overlapText)", attributes: [
                .font: caption2Font,
                .foregroundColor: orange
            ]))
        }
        if let elapsed = BookingElapsedText.string(for: booking, now: now) {
            ns.append(NSAttributedString(string: "  \(elapsed)", attributes: [
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
                text: L10n.string(.bookingCancellationLocked),
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
                text: L10n.string(.bookingCancellationLocked),
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
                text: cancellationDeadlineDisplayText(deadline),
                font: font,
                color: color
            )
        } else {
            appendIconLine(
                to: ns,
                systemName: "tag.fill",
                text: cancellationDeadlineDisplayText(deadline),
                font: font,
                color: secondary
            )
        }
    }

    private func cancellationDeadlineDisplayText(_ deadline: SDCancellationDeadline) -> String {
        let formattedDeadline = Formatting.formatOrtszeit(
            deadline.deadlineAt,
            dateFormat: "d.M. HH:mm",
            timeZone: timeZone(forDeadline: deadline)
        )
        if deadline.isFreeCancellation {
            return L10n.cancellationFreeUntilText(deadlineAt: formattedDeadline)
        }
        if let policy = deadline.policyText, !policy.isEmpty {
            return policy
        }
        return L10n.cancellationPaidUntilText(deadlineAt: formattedDeadline)
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
        return label.isEmpty ? L10n.string(.bookingFieldFallbackDestination) : label
    }

    private var transportOriginLabel: String {
        let label = booking.locationFrom ?? ""
        return label.isEmpty ? booking.bookingType.locationFromLabel : label
    }

    private var transportDestinationLabel: String {
        let label = booking.locationTo ?? ""
        return label.isEmpty ? booking.bookingType.locationToLabel : label
    }

    var body: some View {
        // Summary: reines SwiftUI (kein NSTextView/onTapGesture — sonst verzögerte Listen-Klicks).
        TimelineView(CalendarDayTimelineSchedule()) { context in
            Group {
                if displayMode == .summary {
                    bookingSummaryBody(now: context.date)
                } else {
                    bookingDetailsBody(now: context.date)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func bookingSummaryBody(now: Date) -> some View {
        let stornoLines = BookingStornoSummary.lines(for: booking, now: now)

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(booking.presentationTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if BookingOverlapCaption.isVisible(overlapCount: overlapCount) {
                        BookingOverlapCaption(extraCount: overlapCount)
                    }
                    BookingElapsedLabel(for: booking, now: now)
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

            bookingTrailingMeta
        }
    }

    private func bookingDetailsBody(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                SelectableBookingTextView(
                    attributedString: bookingAttributedDisplayText(now: now),
                    copyText: bookingFullCopyText(now: now)
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                bookingTrailingMeta
            }

        }
    }

    private var bookingTrailingMeta: some View {
        VStack(alignment: .trailing, spacing: 2) {
            ProviderLogo(providerID: booking.provider)
            BookingTypeLabel(booking.bookingType)
                .foregroundStyle(.secondary)
            Text(bookingPriceText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .fixedSize(horizontal: true, vertical: false)
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
    @Environment(\.openURL) private var openURL
    @State private var preferredSearchProvider: ProviderID?

    private var hotelTimeZone: TimeZone {
        HotelTimeZone.resolve(
            fromOffsetSeconds: gap.fromBooking.hotelOffsetSeconds,
            toOffsetSeconds: gap.toBooking.hotelOffsetSeconds
        )
    }

    private var enabledGapSearchProviders: [ProviderID] {
        providerRegistry?.enabledGapSearchProviderIDs() ?? []
    }

    private var linkSuggestions: (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        providerRegistry?.gapDeepLinkSuggestions(
            for: gap,
            kind: effectiveKind,
            preferredProvider: preferredSearchProvider
        ) ?? ([], [])
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
            Text(L10n.gapKindDisplay(effectiveKind))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var gapDetailsBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    CopyableFieldValue(
                        value: displayTitle,
                        kind: .standard,
                        textStyle: .headline,
                        lineLimit: 2
                    )
                    let rangeText = "\(Formatting.formatOrtszeit(gap.gapStart, dateFormat: "d.M.", timeZone: hotelTimeZone)) – \(Formatting.formatOrtszeit(gap.gapEnd, dateFormat: "d.M.", timeZone: hotelTimeZone))"
                    CopyableFieldValue(
                        value: rangeText,
                        kind: .standard,
                        textStyle: .subheadline,
                        foregroundStyle: .secondary,
                        lineLimit: 1
                    )
                }
                Spacer(minLength: 0)
                Button(L10n.string(.commonEdit)) {
                    onEdit()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            CopyableLabeledValue(
                label: L10n.string(.editorType),
                value: L10n.gapKindDisplay(effectiveKind),
                kind: .standard,
                style: .inspector,
                valueTextStyle: .caption
            )

            if let priceText {
                CopyableLabeledValue(
                    label: L10n.string(.bookingDetailPrice),
                    value: priceText,
                    kind: .standard,
                    style: .inspector,
                    valueTextStyle: .caption
                )
            }

            GapSearchControls(
                enabledProviderIDs: enabledGapSearchProviders,
                preferredProviderID: $preferredSearchProvider,
                links: linkSuggestions.links,
                issues: linkSuggestions.issues,
                gapKind: effectiveKind,
                style: .compactTimeline,
                openURL: { openURL($0) }
            )
        }
    }
}

