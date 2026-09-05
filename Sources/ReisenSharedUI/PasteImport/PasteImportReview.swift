import Foundation
import Observation
import SwiftData
import SwiftUI
import ReisenData
import ReisenDomain
import ReisenDiagnostics

/// Sendable Review-Payload ohne SwiftData-Objekte — für macOS-`Window` und iOS-Sheet.
public struct PasteImportReviewPayload: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let draft: BookingEditorDraft
    /// Persistierte Zuordnung nach Datumsfenster; `nil` = offene Buchung.
    public let tripID: UUID?
    /// Gesetzt bei Ergänzen einer Bestandsbuchung.
    public let bookingID: UUID?
    /// Einstiegs-Reise des Neu-Imports (ungefiltert); `save` prüft das Fenster gegen den Editor-Draft.
    public let entryTripID: UUID?
    public let index: Int
    public let total: Int

    public init(
        id: UUID = UUID(),
        draft: BookingEditorDraft,
        tripID: UUID?,
        bookingID: UUID?,
        entryTripID: UUID? = nil,
        index: Int = 1,
        total: Int = 1
    ) {
        self.id = id
        self.draft = draft
        self.tripID = tripID
        self.bookingID = bookingID
        self.entryTripID = entryTripID
        self.index = index
        self.total = total
    }

    public var isEnriching: Bool { bookingID != nil }

    public static func enriching(
        candidate: PasteImportCandidate,
        booking: SDBooking,
        index: Int = 1,
        total: Int = 1
    ) -> PasteImportReviewPayload {
        PasteImportReviewPayload(
            draft: PasteImportEditorPrefill.draft(for: candidate, existing: booking),
            tripID: booking.trip?.id,
            bookingID: booking.id,
            index: index,
            total: total
        )
    }

    public static func creating(
        candidate: PasteImportCandidate,
        tripID: UUID?,
        tripStart: Date?,
        tripEnd: Date?,
        calendar: Calendar = HotelStayDate.calendar,
        index: Int = 1,
        total: Int = 1
    ) -> PasteImportReviewPayload {
        let draft = PasteImportEditorPrefill.draft(for: candidate, existing: nil)
        return PasteImportReviewPayload(
            draft: draft,
            tripID: TripBookingDateWindow.assignedTripID(
                entryTripID: tripID,
                bookingStart: draft.startAt,
                bookingEnd: draft.endAt,
                tripStart: tripStart,
                tripEnd: tripEnd,
                calendar: calendar
            ),
            bookingID: nil,
            entryTripID: tripID,
            index: index,
            total: total
        )
    }
}

/// App-weiter Review-Zustand (macOS-Fenster sieht ContentView-`@State` nicht).
@MainActor
@Observable
public final class PasteImportReviewPresenter {
    public static let windowID = "paste-import-review"
    public static let shared = PasteImportReviewPresenter()

    public private(set) var payload: PasteImportReviewPayload?
    /// Nach Sichern: Host selektiert diese Buchung.
    public private(set) var lastSavedBookingID: UUID?
    public var onQueueAdvance: (() -> Void)?

    public init() {}

    public func present(_ payload: PasteImportReviewPayload) {
        lastSavedBookingID = nil
        self.payload = payload
    }

    public func clear() {
        payload = nil
    }

    public func noteSaved(bookingID: UUID) {
        lastSavedBookingID = bookingID
        payload = nil
        onQueueAdvance?()
    }

    public func cancel() {
        let hadPayload = payload != nil
        payload = nil
        if hadPayload {
            onQueueAdvance?()
        }
    }
}

/// Editor für einen Kandidaten: Ergänzen oder neue Buchung — Persistenz erst bei Sichern.
public struct PasteImportReviewSheet: View {
    let payload: PasteImportReviewPayload
    let onCancel: () -> Void
    let onSaved: (UUID) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var draft: BookingEditorDraft
    @State private var showDiscardConfirm = false
    @State private var pendingPeriodExpand: TripPeriodExpandOnAssign.Proposal?
    @State private var showPeriodExpandConfirm = false
    @State private var persistErrorMessage: String?

    public init(
        payload: PasteImportReviewPayload,
        onCancel: @escaping () -> Void,
        onSaved: @escaping (UUID) -> Void
    ) {
        self.payload = payload
        self.onCancel = onCancel
        self.onSaved = onSaved
        _draft = State(initialValue: payload.draft)
    }

    private var isDirty: Bool { draft != payload.draft }

    private var showsSyncOverwriteHint: Bool {
        guard payload.isEnriching else { return false }
        return draft.provider != .manual
    }

    private var progressTitle: String? {
        guard payload.total > 1 else { return nil }
        return "\(payload.index)/\(payload.total)"
    }

    public var body: some View {
        Group {
            #if os(iOS)
            iosBody
            #else
            macBody
            #endif
        }
        .alert(
            L10n.string(.commonCancel),
            isPresented: $showDiscardConfirm
        ) {
            Button(L10n.string(.commonCancel), role: .cancel) {}
            Button(L10n.string(.commonOk), role: .destructive) {
                onCancel()
            }
        } message: {
            Text(L10n.string(.pasteImportReviewDiscardMessage))
        }
        .alert(
            TripPeriodExpandPrompt.title,
            isPresented: $showPeriodExpandConfirm
        ) {
            Button(TripPeriodExpandPrompt.confirmAction) {
                confirmPeriodExpandAndSave()
            }
            Button(TripPeriodExpandPrompt.declineAction, role: .cancel) {
                declinePeriodExpandAndSaveOpen()
            }
        } message: {
            if let pendingPeriodExpand {
                Text(TripPeriodExpandPrompt.message(for: pendingPeriodExpand))
            }
        }
        .persistFailureAlert(message: $persistErrorMessage)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(UITestingIdentifiers.pasteImportReview)
    }

    #if os(macOS)
    private var macBody: some View {
        BookingEditorForm(
            title: editorTitle,
            showsSyncOverwriteHint: showsSyncOverwriteHint,
            draft: $draft,
            providerReadOnly: payload.isEnriching,
            saveAccessibilityIdentifier: UITestingIdentifiers.pasteImportAccept,
            onCancel: requestCancel,
            onSave: save
        )
        .frame(minWidth: 520, idealHeight: 720, maxHeight: 900)
        .navigationTitle(progressTitle ?? editorTitle)
    }
    #endif

    #if os(iOS)
    private var iosBody: some View {
        NavigationStack {
            BookingEditorForm(
                title: editorTitle,
                showsSyncOverwriteHint: showsSyncOverwriteHint,
                draft: $draft,
                providerReadOnly: payload.isEnriching,
                chrome: .navigation,
                onCancel: requestCancel,
                onSave: save
            )
            .navigationTitle(progressTitle ?? editorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isDirty)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.commonCancel), action: requestCancel)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    #endif

    private var editorTitle: String {
        payload.isEnriching
            ? L10n.string(.editorEditTitle)
            : L10n.string(.editorCreateTitle)
    }

    private func requestCancel() {
        if isDirty {
            showDiscardConfirm = true
            return
        }
        onCancel()
    }

    private func save() throws {
        if let bookingID = payload.bookingID {
            let booking = try fetchBooking(id: bookingID)
            try draft.apply(to: booking, in: modelContext)
            onSaved(booking.id)
            return
        }
        let entryTrip = try fetchTrip(id: payload.entryTripID)
        guard let entryTrip else {
            try createBooking(assignedTo: nil)
            return
        }
        if let proposal = TripPeriodExpandOnAssign.proposalIfNeeded(
            bookingStart: draft.startAt,
            bookingEnd: draft.endAt,
            tripStart: entryTrip.startDate,
            tripEnd: entryTrip.endDate
        ) {
            pendingPeriodExpand = proposal
            showPeriodExpandConfirm = true
            return
        }
        try createBooking(assignedTo: entryTrip)
    }

    private func confirmPeriodExpandAndSave() {
        guard let proposal = pendingPeriodExpand else { return }
        do {
            guard let entryTrip = try fetchTrip(id: payload.entryTripID) else {
                try createBooking(assignedTo: nil)
                return
            }
            entryTrip.startDate = proposal.start
            entryTrip.endDate = proposal.end
            try createBooking(assignedTo: entryTrip)
        } catch {
            SharedUIPersistDiagnostics.recordFailure(
                component: "PasteImportReview",
                operation: "paste_import_period_expand_save",
                error: error
            )
            persistErrorMessage = error.localizedDescription
        }
    }

    private func declinePeriodExpandAndSaveOpen() {
        do {
            try createBooking(assignedTo: nil)
        } catch {
            SharedUIPersistDiagnostics.recordFailure(
                component: "PasteImportReview",
                operation: "paste_import_save_open",
                error: error
            )
            persistErrorMessage = error.localizedDescription
        }
    }

    private func createBooking(assignedTo trip: SDTrip?) throws {
        let createdID = try BookingEditorDraft.createBooking(
            from: draft,
            trip: trip,
            in: modelContext
        )
        pendingPeriodExpand = nil
        showPeriodExpandConfirm = false
        onSaved(createdID)
    }

    private func fetchBooking(id: UUID) throws -> SDBooking {
        let found = try modelContext.fetch(
            FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == id })
        ).first
        guard let found else {
            throw PasteImportReviewPersistError.bookingMissing
        }
        return found
    }

    private func fetchTrip(id: UUID?) throws -> SDTrip? {
        guard let id else { return nil }
        let found = try modelContext.fetch(
            FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == id })
        ).first
        guard let found else {
            throw PasteImportReviewPersistError.tripMissing
        }
        return found
    }
}

private enum PasteImportReviewPersistError: LocalizedError {
    case bookingMissing
    case tripMissing

    var errorDescription: String? {
        switch self {
        case .bookingMissing:
            L10n.string(.pasteImportErrorMatchMissing)
        case .tripMissing:
            L10n.string(.tripTripMissing)
        }
    }
}
