import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData
import ReisenSharedUI
import ReisenProviders
import ReisenAppCore
import ReisenDiagnostics
import AppKit
import Foundation

private enum TripTimelineBatchError: LocalizedError {
    case bookingMissing

    var errorDescription: String? {
        switch self {
        case .bookingMissing:
            return L10n.string(.tripBookingMissing)
        }
    }
}

struct TripDetailView: View {
    enum Mode {
        case list
        case detail
    }

    let mode: Mode
    @Bindable var trip: SDTrip
    @Binding var selectedTimelineIDs: Set<String>
    @Binding var gapEditorPayload: GapEditorPayload?
    @Binding var bookingEditorSession: BookingEditorSession?
    @Binding var createDraftTypedTitle: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.providerSessionHub) private var sessionHub
    @Environment(\.openURL) private var openURL
    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]
    @State private var cancelRequest: BookingPortalCancelRequest?
    @Query(sort: \SDGap.gapStart, order: .forward) private var allGaps: [SDGap]

    private var sortedBookings: [SDBooking] {
        trip.timelineBookings()
    }

    @AppStorage(AppSettingsKeys.convertAmountsToPreferredCurrency) private var convertAmountsToPreferredCurrency = false
    @AppStorage(AppSettingsKeys.preferredCurrencyCode) private var preferredCurrencyCodeStored = ""
    @State private var tripCostResult: TripCostOverviewResult = .empty
    @State private var tripCostRefreshToken = UUID()

    private var tripCostSummary: TripCostSummary {
        TripCostTimelineSummary.make(trip: trip, bookings: sortedBookings, allGaps: allGaps)
    }

    private func refreshTripCost() {
        TripCostOverviewRefresh.run(
            summary: tripCostSummary,
            convertEnabled: convertAmountsToPreferredCurrency,
            preferredCurrencyStored: preferredCurrencyCodeStored,
            rates: ExchangeRateService.sharedClient,
            setToken: { tripCostRefreshToken = $0 },
            setResult: { tripCostResult = $0 },
            currentToken: { tripCostRefreshToken }
        )
    }

    private var savedGapsByKey: [String: SDGap] {
        TripGapTimeline.savedGapsByKey(allGaps: allGaps, tripID: trip.id)
    }

    private var overlapPartnerTitlesByBookingID: [UUID: [String]] {
        let partnerIDs = BookingDayOverlap.partnerIDsByID(sdBookings: allBookings)
        let titleByID = Dictionary(uniqueKeysWithValues: allBookings.map { ($0.id, $0.presentationTitle) })
        return Dictionary(uniqueKeysWithValues: partnerIDs.keys.map { bookingID in
            (
                bookingID,
                BookingOverlapCaption.partnerTitles(
                    for: bookingID,
                    partnerIDsByBookingID: partnerIDs,
                    titleByID: titleByID
                )
            )
        })
    }

    private var gaps: [ComputedGap] {
        TripGapTimeline.computedGaps(trip: trip, bookings: sortedBookings)
    }

    private func selectTimelineID(_ id: String) {
        selectedTimelineIDs = [id]
    }

    private func isTimelineBookingID(_ id: String) -> Bool {
        UUID(uuidString: id) != nil
    }

    private func isTimelineGapID(_ id: String) -> Bool {
        id.hasPrefix("gap|")
    }

    private func editBooking(_ booking: SDBooking) {
        selectTimelineID(booking.id.uuidString)
        bookingEditorSession = .edit(bookingID: booking.id)
    }

    private func startCreateBooking(prefillStart: Date?, prefillEnd: Date?) {
        createDraftTypedTitle = ""
        bookingEditorSession = .create(prefillStart: prefillStart, prefillEnd: prefillEnd)
        BookingCreateDraftDiagnostics.recordSelected(reason: "timeline_create_draft")
        // List kennt den Create-Draft-Tag erst nach dem Session-Update.
        Task { @MainActor in
            await Task.yield()
            guard case .create = bookingEditorSession else { return }
            var selection = selectedTimelineIDs
            BookingCreateDraftSelection.selectCreateDraft(into: &selection)
            selectedTimelineIDs = selection
        }
    }

    private func performRemoveBookingFromTrip(_ booking: SDBooking) throws {
        let oldTripID = booking.trip?.id
        booking.trip = nil
        try modelContext.save()
        if let oldTripID {
            try AutoGapReconcileTrigger.run(tripIDs: [oldTripID], in: modelContext)
            try modelContext.save()
        }
    }

    private func clearSelectionAfterRemoving(_ removedID: String, fallbackTimelineID: String?) {
        guard selectedTimelineIDs.contains(removedID) else { return }
        selectedTimelineIDs.remove(removedID)
        if selectedTimelineIDs.isEmpty,
           let fallbackTimelineID,
           fallbackTimelineID != removedID {
            selectedTimelineIDs = [fallbackTimelineID]
        }
    }

    private func removeBookingFromTrip(_ booking: SDBooking, fallbackTimelineID: String?) {
        do {
            try performRemoveBookingFromTrip(booking)
        } catch {
            persistErrorMessage = error.localizedDescription
        }

        clearSelectionAfterRemoving(booking.id.uuidString, fallbackTimelineID: fallbackTimelineID)

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

    private func requestBatchRemoveFromTrip(_ timelineIDs: Set<String>) {
        let bookingIDs = timelineIDs.compactMap { UUID(uuidString: $0) }
        guard !bookingIDs.isEmpty else { return }
        pendingBatchRemoveBookingIDs = bookingIDs
        showBatchRemoveConfirmation = true
    }

    private func requestBatchDeleteBookings(_ bookingIDs: Set<UUID>) {
        guard bookingIDs.count > 1 else { return }
        pendingBatchDeleteBookingIDs = bookingIDs
        showBatchDeleteConfirmation = true
    }

    @State private var showAssignBookings = false
    @State private var assignPreselectedBookingIDs: Set<UUID> = []
    @State private var pendingDeleteBookingID: UUID?
    @State private var showDeleteConfirmation = false
    @State private var pendingRemoveFromTripBookingID: UUID?
    @State private var showRemoveFromTripConfirmation = false
    @State private var pendingBatchRemoveBookingIDs: [UUID] = []
    @State private var showBatchRemoveConfirmation = false
    @State private var pendingBatchDeleteBookingIDs: Set<UUID> = []
    @State private var showBatchDeleteConfirmation = false
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
        selectedTimelineIDs.remove(bookingIDToDelete.uuidString)
        if selectedTimelineIDs.isEmpty, let newSelection {
            selectedTimelineIDs = [newSelection]
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

    private func confirmBatchRemoveFromTrip() {
        let ids = pendingBatchRemoveBookingIDs
        pendingBatchRemoveBookingIDs = []

        let bookings: [SDBooking]
        do {
            bookings = try ids.map { id in
                guard let booking = trip.resolvedBookings.first(where: { $0.id == id }) else {
                    throw TripTimelineBatchError.bookingMissing
                }
                return booking
            }
        } catch {
            persistErrorMessage = error.localizedDescription
            Task {
                await DiagnosticLogger.shared.record(
                    TripBookingListDiagnostics.removeFromTripBatch(
                        result: .failed,
                        count: 0,
                        errorType: String(describing: type(of: error))
                    )
                )
            }
            return
        }

        let requestedCount = bookings.count
        Task {
            await DiagnosticLogger.shared.record(
                TripBookingListDiagnostics.removeFromTripBatch(result: .started, count: requestedCount)
            )
        }

        var removedCount = 0
        do {
            for booking in bookings {
                try performRemoveBookingFromTrip(booking)
                removedCount += 1
                selectedTimelineIDs.remove(booking.id.uuidString)
                if case .edit(let editingID, _) = bookingEditorSession, editingID == booking.id {
                    bookingEditorSession = nil
                }
            }
            if selectedTimelineIDs.isEmpty, let first = sortedBookings.first?.id.uuidString {
                selectedTimelineIDs = [first]
            }
            Task {
                await DiagnosticLogger.shared.record(
                    TripBookingListDiagnostics.removeFromTripBatch(result: .succeeded, count: removedCount)
                )
            }
        } catch {
            persistErrorMessage = error.localizedDescription
            Task {
                await DiagnosticLogger.shared.record(
                    TripBookingListDiagnostics.removeFromTripBatch(
                        result: .failed,
                        count: removedCount,
                        errorType: String(describing: type(of: error))
                    )
                )
            }
        }
    }

    private func confirmBatchDeleteBookings() {
        let ids = pendingBatchDeleteBookingIDs
        let bookingsByID = Dictionary(uniqueKeysWithValues: trip.resolvedBookings.map { ($0.id, $0) })
        let result = SelectionBatchDeleteHandlers.deleteTripBookings(ids: ids) { id in
            guard let booking = bookingsByID[id] else {
                throw TripTimelineBatchError.bookingMissing
            }
            try BookingDeletion.perform(booking: booking, in: modelContext)
        }
        Task {
            for event in result.events {
                await DiagnosticLogger.shared.record(event)
            }
        }

        let remaining = SelectionBatchDeletion.remainingIDs(from: ids, outcome: result.outcome)
        selectedTimelineIDs = Set(remaining.map(\.uuidString))
        pendingBatchDeleteBookingIDs = []
        if case .failed(_, let errorDescription) = result.outcome {
            persistErrorMessage = errorDescription
            return
        }
        if let first = trip.timelineBookings().first?.id.uuidString {
            selectedTimelineIDs = [first]
        }
        if case .edit(let editingID, _) = bookingEditorSession, ids.contains(editingID) {
            bookingEditorSession = nil
        }
    }

    var body: some View {
        let isCreatingBooking: Bool = {
            if case .create = bookingEditorSession { return true }
            return false
        }()
        let timelineItems = timelineItems(
            gaps: gaps,
            bookings: sortedBookings,
            includesCreateDraft: isCreatingBooking
        )
        let primaryTimelineID = TimelineSelection.primaryID(in: selectedTimelineIDs)
        let selectedTimelineItem: TripTimelineItem? = {
            guard let primaryTimelineID else { return nil }
            return timelineItems.first { $0.id == primaryTimelineID }
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
                            startCreateBooking(prefillStart: nil, prefillEnd: nil)
                        }
                        Button(L10n.string(.actionAssignBookings)) {
                            showAssignBookings = true
                        }
                        .disabled(openBookingsCandidates().isEmpty)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    bookingsList(timelineItems: timelineItems)
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
                        startCreateBooking(prefillStart: nil, prefillEnd: nil)
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
                guard selectedTimelineIDs.isEmpty, let firstBookingTimelineID else { return }
                selectedTimelineIDs = [firstBookingTimelineID]
            }
            .onChange(of: bookingEditorSession) { _, session in
                guard case .create = session else { return }
                guard !BookingCreateDraftSelection.isCreateDraftSelection(selectedTimelineIDs) else { return }
                var selection = selectedTimelineIDs
                BookingCreateDraftSelection.selectCreateDraft(into: &selection)
                selectedTimelineIDs = selection
            }
            .onChange(of: trip.id) { _, _ in
                bookingEditorSession = nil
                guard selectedTimelineIDs.isEmpty, let firstBookingTimelineID else { return }
                selectedTimelineIDs = [firstBookingTimelineID]
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
            .onReceive(NotificationCenter.default.publisher(for: .reisenRequestRemoveBookingFromTrip)) { note in
                if let bookingIDs = note.object as? [UUID], bookingIDs.count > 1 {
                    requestBatchRemoveFromTrip(Set(bookingIDs.map(\.uuidString)))
                } else if let bookingID = (note.object as? [UUID])?.first ?? note.object as? UUID,
                          let booking = trip.resolvedBookings.first(where: { $0.id == bookingID }) {
                    requestRemoveBookingFromTrip(booking)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .reisenRequestDeleteBooking)) { note in
                if let bookingIDs = note.object as? [UUID], bookingIDs.count > 1 {
                    requestBatchDeleteBookings(Set(bookingIDs))
                } else if let bookingID = (note.object as? [UUID])?.first ?? note.object as? UUID,
                          let booking = trip.resolvedBookings.first(where: { $0.id == bookingID }) {
                    requestDeleteBooking(booking)
                }
            }
        } else if selectedTimelineIDs.count > 1 {
            let selectionKind = TripTimelineContextActions.kind(
                selectedIDs: selectedTimelineIDs,
                isBookingID: isTimelineBookingID,
                isGapID: isTimelineGapID
            )
            TripBookingMultiSelectionSummary(
                selectedCount: selectedTimelineIDs.count,
                onRemoveFromTrip: selectionKind == .multipleBookingsOnly
                    ? { requestBatchRemoveFromTrip(selectedTimelineIDs) }
                    : nil
            )
            .navigationTitle(trip.title)
        } else {
            BookingDetailPanel(
                selectedTimelineItem: selectedTimelineItem,
                trip: trip,
                overlapPartnerTitlesByBookingID: overlapPartnerTitlesByBookingID,
                bookingEditorSession: $bookingEditorSession,
                selectedTimelineIDs: $selectedTimelineIDs,
                createDraftTypedTitle: $createDraftTypedTitle,
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
        .confirmationDialog(
            BookingTripActions.removeFromTripTitle,
            isPresented: $showBatchRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.string(.commonRemove), role: .destructive, action: confirmBatchRemoveFromTrip)
            Button(L10n.string(.commonCancel), role: .cancel) {
                pendingBatchRemoveBookingIDs = []
            }
        } message: {
            Text(L10n.format(.tripBatchRemoveFromTripHelp, pendingBatchRemoveBookingIDs.count))
        }
        .confirmationDialog(
            L10n.format(.tripSelectedTimelineBookings, pendingBatchDeleteBookingIDs.count),
            isPresented: $showBatchDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.string(.commonDelete), role: .destructive, action: confirmBatchDeleteBookings)
            Button(L10n.string(.commonCancel), role: .cancel) {
                pendingBatchDeleteBookingIDs = []
            }
        }
        .persistFailureAlert(message: $persistErrorMessage)
        .bookingPortalCancelSheet($cancelRequest)
    }

    @ViewBuilder
    private func bookingsList(timelineItems: [TripTimelineItem]) -> some View {
        List(selection: $selectedTimelineIDs) {
            ForEach(timelineItems) { item in
                TimelineRowLabel(
                    item: item,
                    createDraftTitle: BookingCreateDraftSelection.displayTitle(
                        typedTitle: createDraftTypedTitle
                    ),
                    overlapPartnerTitlesByBookingID: overlapPartnerTitlesByBookingID,
                    gapPresentation: gapPresentation(for:),
                    onEditGap: { payload in
                        gapEditorPayload = payload
                    }
                )
                .tag(item.id)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .accessibilityIdentifier(timelineItemIdentifier(item))
                .accessibilityAddTraits(
                    selectedTimelineIDs.contains(item.id) ? [.isSelected] : []
                )
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { ids in
            timelineSelectionContextMenu(ids: ids, timelineItems: timelineItems)
        }
    }

    @ViewBuilder
    private func timelineSelectionContextMenu(
        ids: Set<String>,
        timelineItems: [TripTimelineItem]
    ) -> some View {
        let kind = TripTimelineContextActions.kind(
            selectedIDs: ids,
            isBookingID: isTimelineBookingID,
            isGapID: isTimelineGapID
        )
        let actions = TripTimelineContextActions.actions(for: kind)
        switch kind {
        case .singleBooking:
            if let id = ids.first,
               let item = timelineItems.first(where: { $0.id == id }),
               case .booking(let booking) = item {
                if actions.contains(.edit) {
                    Button(L10n.string(.commonEdit)) { editBooking(booking) }
                }
                if actions.contains(.addBooking) {
                    Button(L10n.string(.actionAddBooking)) {
                        startCreateBooking(
                            prefillStart: nil,
                            prefillEnd: nil
                        )
                    }
                }
                if actions.contains(.copy) {
                    BookingCopyConfirmationMenuItems(booking: booking)
                }
                if actions.contains(.openPortal), let url = booking.browserURL {
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
                if actions.contains(.removeFromTrip) {
                    Button(role: .destructive) {
                        requestRemoveBookingFromTrip(booking)
                    } label: {
                        Text(L10n.string(.actionRemoveFromTrip))
                    }
                }
                if actions.contains(.deleteBooking) {
                    Button(L10n.string(.actionDeleteEllipsis), role: .destructive) {
                        requestDeleteBooking(booking)
                    }
                    .accessibilityIdentifier(UITestingIdentifiers.deleteBookingMenu)
                }
            }
        case .singleGap:
            if let id = ids.first,
               let item = timelineItems.first(where: { $0.id == id }),
               case .gap(let gap) = item {
                let editPayload = gapPresentation(for: gap).editorPayload(for: gap)
                if actions.contains(.editGap) {
                    Button(L10n.string(.actionEditGap)) {
                        selectTimelineID(item.id)
                        gapEditorPayload = editPayload
                    }
                }
                if actions.contains(.addBooking) {
                    Button(L10n.string(.actionAddBooking)) {
                        startCreateBooking(
                            prefillStart: gap.gapStart,
                            prefillEnd: gap.gapEnd
                        )
                    }
                }
            }
        case .multipleBookingsOnly:
            if actions.contains(.batchRemoveFromTrip) {
                Button(role: .destructive) {
                    requestBatchRemoveFromTrip(ids)
                } label: {
                    Text(L10n.string(.actionRemoveFromTrip))
                }
            }
            if actions.contains(.batchDeleteBooking) {
                Button(L10n.string(.actionDeleteEllipsis), role: .destructive) {
                    requestBatchDeleteBookings(Set(ids.compactMap(UUID.init(uuidString:))))
                }
            }
        case .empty, .mixedOrGapsOnly:
            EmptyView()
        }
    }

    private func timelineItems(
        gaps: [ComputedGap],
        bookings: [SDBooking],
        includesCreateDraft: Bool
    ) -> [TripTimelineItem] {
        TripTimelineItem.displayItems(
            bookings: bookings,
            gaps: gaps,
            includesCreateDraft: includesCreateDraft
        )
    }

    private func timelineItemIdentifier(_ item: TripTimelineItem) -> String {
        switch item {
        case .booking(let booking):
            return UITestingIdentifiers.timelineBookingRow(booking.id)
        case .createDraft:
            return UITestingIdentifiers.bookingCreateDraftTimeline
        case .gap:
            return "reisen.gap.\(item.id)"
        }
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
                VStack(alignment: .leading, spacing: 2) {
                    overviewFact(
                        label: L10n.string(.bookingDetailPrice),
                        value: TripCostDisplayText.primaryLine(for: tripCostResult)
                    )
                    if let secondary = TripCostDisplayText.secondaryLine(for: tripCostResult) {
                        Text(secondary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .help(secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .onAppear { refreshTripCost() }
                .onChange(of: convertAmountsToPreferredCurrency) { _, _ in refreshTripCost() }
                .onChange(of: preferredCurrencyCodeStored) { _, _ in refreshTripCost() }
                .onChange(of: tripCostSummary.costFingerprint) { _, _ in refreshTripCost() }
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
    let createDraftTitle: String
    let overlapPartnerTitlesByBookingID: [UUID: [String]]
    let gapPresentation: (ComputedGap) -> GapPresentation
    let onEditGap: (GapEditorPayload) -> Void

    var body: some View {
        switch item {
        case .booking(let booking):
            BookingRow(
                booking: booking,
                displayMode: .summary,
                partnerTitles: overlapPartnerTitlesByBookingID[booking.id] ?? [],
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

        case .createDraft:
            Label(createDraftTitle, systemImage: "plus.circle")
                .font(.body.weight(.medium))
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
    let overlapPartnerTitlesByBookingID: [UUID: [String]]
    @Binding var bookingEditorSession: BookingEditorSession?
    @Binding var selectedTimelineIDs: Set<String>
    @Binding var createDraftTypedTitle: String
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
        .onChange(of: selectedTimelineIDs) { _, newIDs in
            guard case .create = bookingEditorSession else { return }
            guard !BookingCreateDraftSelection.isCreateDraftSelection(newIDs) else { return }
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
            let draft = prefilledDraft ?? BookingEditorDraft.createDefault(
                tripStartDate: trip.startDate,
                prefillStart: prefillStart,
                prefillEnd: prefillEnd
            )
            bookingEditorDraft = draft
            createDraftTypedTitle = draft.title
        case .edit(let bookingID, let prefilledDraft):
            guard resetDraft || bookingEditorDraft == nil else { return }
            if let booking = selectedBooking, booking.id == bookingID {
                bookingEditorDraft = prefilledDraft ?? BookingEditorDraft.fromExisting(booking)
            } else {
                bookingEditorDraft = nil
            }
        case nil:
            bookingEditorDraft = nil
            createDraftTypedTitle = ""
        }
    }

    private var editorTitle: String {
        switch bookingEditorSession {
        case .create:
            return BookingCreateDraftSelection.displayTitle(typedTitle: bookingEditorDraft?.title)
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
            set: { newDraft in
                bookingEditorDraft = newDraft
                if case .create = bookingEditorSession {
                    createDraftTypedTitle = newDraft.title
                }
            }
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
                                partnerTitles: overlapPartnerTitlesByBookingID[booking.id] ?? [],
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
                        case .createDraft:
                            EmptyView()
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
        let wasCreateDraft = {
            if case .create = bookingEditorSession { return true }
            return false
        }()
        bookingEditorSession = nil
        bookingEditorDraft = nil
        pendingPeriodExpand = nil
        showPeriodExpandConfirm = false
        if wasCreateDraft {
            createDraftTypedTitle = ""
            if BookingCreateDraftSelection.isCreateDraftSelection(selectedTimelineIDs) {
                if let first = trip.timelineBookings().first?.id.uuidString {
                    selectedTimelineIDs = [first]
                } else {
                    selectedTimelineIDs = []
                }
            }
        }
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
        selectedTimelineIDs = [newID.uuidString]
        clearEditor()
    }
}

private struct BookingRow: View {
    let booking: SDBooking
    let displayMode: TimelineRowDisplayMode
    let partnerTitles: [String]
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

        if BookingOverlapCaption.isVisible(partnerTitles: partnerTitles) {
            parts.append(BookingOverlapCaption.labelText(partnerTitles: partnerTitles))
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

        // Overlap visually via BookingOverlapCaption (summary + details); Copy behält labelText.
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
                    if BookingOverlapCaption.isVisible(partnerTitles: partnerTitles) {
                        BookingOverlapCaption(partnerTitles: partnerTitles)
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
            if BookingOverlapCaption.isVisible(partnerTitles: partnerTitles) {
                BookingOverlapCaption(partnerTitles: partnerTitles)
            }
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

