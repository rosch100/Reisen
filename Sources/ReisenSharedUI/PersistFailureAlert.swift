import SwiftUI
import ReisenDomain

public struct PersistFailureAlert: ViewModifier {
    @Binding var message: String?

    public init(message: Binding<String?>) {
        _message = message
    }

    public func body(content: Content) -> some View {
        content.alert(L10n.string(.tripAssignFailed), isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button(L10n.string(.commonOk), role: .cancel) { message = nil }
        } message: {
            if let message {
                Text(message)
            }
        }
    }
}

public extension View {
    func persistFailureAlert(message: Binding<String?>) -> some View {
        modifier(PersistFailureAlert(message: message))
    }
}
