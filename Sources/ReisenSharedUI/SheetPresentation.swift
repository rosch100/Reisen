import SwiftUI

public extension View {
    /// iPhone-friendly sheet detents; no-op on macOS.
    @ViewBuilder
    func reisenSheetDetents() -> some View {
#if os(iOS)
        self.presentationDetents([.medium, .large])
#else
        self
#endif
    }
}
