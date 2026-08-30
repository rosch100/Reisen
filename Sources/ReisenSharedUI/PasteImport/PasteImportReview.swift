import Foundation
import Observation
import SwiftData
import SwiftUI
import ReisenData
import ReisenDomain

/// Sendable Review-Payload ohne SwiftData-Objekte — für macOS-`Window` und iOS-Sheet.
public struct PasteImportReviewPayload: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let draft: BookingEditorDraft
    /// `nil` = offene Buchung.
    public let tripID: UUID?
    /// Gesetzt bei Ergänzen einer Bestandsbuchung.
    public let bookingID: UUID?
    public let index: Int
    public let total: Int

    public init(
        id: UUID = UUID(),
        draft: BookingEditorDraft,
        tripID: UUID?,
        bookingID: UUID?,
        index: Int = 1,
        total: Int = 1
    ) {
        self.id = id
        self.draft = draft
        self.tripID = tripID
        self.bookingID = bookingID
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
        index: Int = 1,
        total: Int = 1
    ) -> PasteImportReviewPayload {
        PasteImportReviewPayload(
            draft: PasteImportEditorPrefill.draft(for: candidate, existing: nil),
            tripID: tripID,
            bookingID: nil,
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
    @State private var navigationError: String?

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
        #if os(iOS)
        iosBody
        #else
        macBody
        #endif
    }

    #if os(macOS)
    private var macBody: some View {
        BookingEditorForm(
            title: editorTitle,
            showsSyncOverwriteHint: showsSyncOverwriteHint,
            draft: $draft,
            providerReadOnly: payload.isEnriching,
            onCancel: requestCancel,
            onSave: save
        )
        .frame(minWidth: 520, minHeight: 620)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string(.commonSave)) {
                        performSaveFromNavigation()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let navigationError {
                    Text(navigationError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background)
                }
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
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func performSaveFromNavigation() {
        do {
            try draft.validate()
            try save()
            navigationError = nil
        } catch {
            navigationError = (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
        }
    }
    #endif

    private var editorTitle: String {
        payload.isEnriching
            ? L10n.string(.editorEditTitle)
            : L10n.string(.editorCreateTitle)
    }

    private func requestCancel() {
        #if os(iOS)
        if isDirty {
            showDiscardConfirm = true
            return
        }
        #endif
        onCancel()
    }

    private func save() throws {
        if let bookingID = payload.bookingID {
            let booking = try fetchBooking(id: bookingID)
            try draft.apply(to: booking, in: modelContext)
            onSaved(booking.id)
            return
        }
        let trip = try fetchTrip(id: payload.tripID)
        let createdID = try BookingEditorDraft.createBooking(
            from: draft,
            trip: trip,
            in: modelContext
        )
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
