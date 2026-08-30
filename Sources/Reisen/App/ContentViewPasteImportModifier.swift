import SwiftUI
import ReisenPasteImport
import ReisenSharedUI
import ReisenDomain

/// Paste-Import-Modifier für ContentView — eigener Typ, damit der ContentView-Body type-checkt.
struct ContentViewPasteImportModifier: ViewModifier {
    @Bindable var session: PasteImportSession
    @Binding var bookingEditorSession: BookingEditorSession?
    let onReviewQueue: () -> Void
    let onSelectSavedBooking: (UUID) -> Void
    let onDropped: ([URL]) -> Void
    let onExternal: () -> Void

    func body(content: Content) -> some View {
        content
            .pasteImportInboxAndDrop(
                isSessionActive: session.isActive,
                onDropped: onDropped,
                onExternal: onExternal
            )
            .pasteImportFlow(session: session, onReviewQueue: onReviewQueue)
            .onChange(of: bookingEditorSession) { _, newSession in
                guard newSession == nil else { return }
                onReviewQueue()
            }
            .onChange(of: session.isReviewing) { _, reviewing in
                // Neuer Paste/`reset` schließt Review ohne Persistenz.
                guard !reviewing, PasteImportReviewPresenter.shared.payload != nil else { return }
                PasteImportReviewPresenter.shared.clear()
            }
            .background {
                PasteImportReviewHostBridge(
                    onAdvance: {
                        if let id = PasteImportReviewPresenter.shared.lastSavedBookingID {
                            onSelectSavedBooking(id)
                        }
                        onReviewQueue()
                    }
                )
            }
    }
}
