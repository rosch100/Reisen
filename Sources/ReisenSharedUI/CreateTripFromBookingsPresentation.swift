import SwiftUI
import ReisenDomain
import ReisenData

public extension View {
    /// Sheet + failure alert for creating a trip from open-booking selection.
    func createTripFromBookingsPresentation(
        seed: Binding<TripCreateSeed?>,
        showFailed: Binding<Bool>,
        onSaved: @escaping (SDTrip) -> Void
    ) -> some View {
        sheet(item: seed) { seed in
            TripEditorSheet(mode: .create, seed: seed, onSaved: onSaved)
                .reisenSheetDetents()
        }
        .alert(L10n.string(.tripCreateFromBookingsFailed), isPresented: showFailed) {
            Button(L10n.string(.commonOk), role: .cancel) {}
        }
    }
}
