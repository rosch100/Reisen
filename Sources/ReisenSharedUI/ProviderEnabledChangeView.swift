import SwiftUI
import ReisenDomain

public extension View {
    func onProviderEnabledChange(perform action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .providerEnabledDidChange)) { _ in
            action()
        }
    }

    func onProviderEnabledChange(bump epoch: Binding<Int>) -> some View {
        onProviderEnabledChange { epoch.wrappedValue &+= 1 }
    }

    func onProviderEnabledChange(
        bump epoch: Binding<Int>,
        perform action: @escaping () -> Void
    ) -> some View {
        onProviderEnabledChange(bump: epoch)
            .onChange(of: epoch.wrappedValue) { _, _ in action() }
    }
}
