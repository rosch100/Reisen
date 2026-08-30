import SwiftUI
import ReisenSharedUI

/// Bindet den app-weiten Review-Presenter an ContentView, ohne den Body zu überlasten.
struct PasteImportReviewHostBridge: View {
    let onAdvance: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                PasteImportReviewPresenter.shared.onQueueAdvance = onAdvance
            }
            .onDisappear {
                PasteImportReviewPresenter.shared.onQueueAdvance = nil
            }
    }
}
