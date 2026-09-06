import SwiftUI
import ReisenDomain

/// Sync-Banner-Hinweis: Passkey geht in der eingebetteten WebView nicht.
public struct SyncApplePasskeyHintLabel: View {
    public init() {}

    public var body: some View {
        Text(L10n.string(.syncApplePasskeyHint))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(UITestingIdentifiers.syncApplePasskeyHint)
    }
}
