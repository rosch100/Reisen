import SwiftUI
import ReisenDomain

/// Einmaliges Disclosure vor der ersten Provider-WebView-Anmeldung.
public struct ProviderLoginDisclosureModifier: ViewModifier {
    @AppStorage(ProviderLoginDisclosureKeys.accepted) private var disclosureAccepted = false
    @State private var showDisclosure = false

    private let isActive: Bool

    public init(isActive: Bool = true) {
        self.isActive = isActive
    }

    public func body(content: Content) -> some View {
        content
            .onAppear {
                presentIfNeeded()
            }
            .onChange(of: isActive) { _, active in
                if active {
                    presentIfNeeded()
                }
            }
            .alert(ProviderLoginDisclosure.title, isPresented: $showDisclosure) {
                Button(ProviderLoginDisclosure.acceptButtonTitle) {
                    ProviderLoginDisclosure.accept()
                    disclosureAccepted = true
                }
            } message: {
                Text(ProviderLoginDisclosure.message)
            }
    }

    private func presentIfNeeded() {
        guard isActive, !disclosureAccepted else { return }
        showDisclosure = true
    }
}

extension View {
    public func providerLoginDisclosure(isActive: Bool = true) -> some View {
        modifier(ProviderLoginDisclosureModifier(isActive: isActive))
    }
}
