import SwiftData
import SwiftUI
import ReisenData
import ReisenDomain

/// Editor für einen Kandidaten: Ergänzen einer Bestandsbuchung oder eine neue Buchung.
public struct PasteImportReview: Identifiable {
    public let id = UUID()
    public let draft: BookingEditorDraft
    /// `nil` legt eine neue Buchung an.
    public let booking: SDBooking?
    /// Reise der neuen Buchung aus dem Einstieg; `nil` heißt „offene Buchung“.
    public let trip: SDTrip?

    public init(draft: BookingEditorDraft, booking: SDBooking?, trip: SDTrip?) {
        self.draft = draft
        self.booking = booking
        self.trip = trip
    }

    /// Ergänzen einer eindeutigen Bestandsbuchung (ohne Reisewechsel).
    public static func enriching(
        candidate: PasteImportCandidate,
        booking: SDBooking
    ) -> PasteImportReview {
        PasteImportReview(
            draft: PasteImportEditorPrefill.draft(for: candidate, existing: booking),
            booking: booking,
            trip: nil
        )
    }

    /// Neue Buchung aus dem Kandidaten; `trip == nil` heißt offene Buchung.
    public static func creating(
        candidate: PasteImportCandidate,
        trip: SDTrip?
    ) -> PasteImportReview {
        PasteImportReview(
            draft: PasteImportEditorPrefill.draft(for: candidate, existing: nil),
            booking: nil,
            trip: trip
        )
    }
}

public struct PasteImportReviewSheet: View {
    let review: PasteImportReview
    let onFinished: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var draft: BookingEditorDraft

    public init(review: PasteImportReview, onFinished: @escaping () -> Void) {
        self.review = review
        self.onFinished = onFinished
        _draft = State(initialValue: review.draft)
    }

    private var showsSyncOverwriteHint: Bool {
        guard let booking = review.booking else { return false }
        return booking.provider != .manual
    }

    public var body: some View {
        BookingEditorForm(
            title: review.booking == nil
                ? L10n.string(.editorCreateTitle)
                : L10n.string(.editorEditTitle),
            showsSyncOverwriteHint: showsSyncOverwriteHint,
            draft: $draft,
            providerReadOnly: review.booking != nil,
            onCancel: onFinished,
            onSave: {
                if let booking = review.booking {
                    try draft.apply(to: booking, in: modelContext)
                } else {
                    try BookingEditorDraft.createBooking(
                        from: draft,
                        trip: review.trip,
                        in: modelContext
                    )
                }
                onFinished()
            }
        )
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }
}
