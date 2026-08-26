import SwiftUI

import ReisenAppCore
import ReisenDomain
import ReisenProviders

/// Toggles für Buchungsportale. SSOT: `AppSettingsKeys.providerEnabledKey`.
public struct ProviderEnabledSettingsSection: View {
    @Environment(\.providerRegistry) private var providerRegistry

    public init() {}

    public var body: some View {
        if let registry = providerRegistry, !registry.syncProviderIDs.isEmpty {
            Section {
                ForEach(registry.syncProviderIDs, id: \.self) { id in
                    ProviderEnabledToggle(
                        providerID: id,
                        displayName: registry.provider(id: id)?.displayName ?? id.displayName
                    )
                }
            } header: {
                Text("Buchungsportale")
            } footer: {
                Text(
                    "Nur aktivierte Portale erscheinen unter Sync und werden synchronisiert. "
                        + "Eine installierte Provider-App ersetzt nicht die Anmeldung in der WebView."
                )
            }
        }
    }
}

private struct ProviderEnabledToggle: View {
    let providerID: ProviderID
    let displayName: String

    @Environment(\.syncStore) private var syncStore
    @Environment(\.providerNativeAppPresence) private var nativeAppPresence
    @AppStorage private var isEnabled: Bool

    init(providerID: ProviderID, displayName: String) {
        self.providerID = providerID
        self.displayName = displayName
        self._isEnabled = AppStorage(
            wrappedValue: true,
            AppSettingsKeys.providerEnabledKey(for: providerID)
        )
    }

    private var isSyncingThisProvider: Bool {
        syncStore?.syncingProviderID == providerID && syncStore?.isSyncing == true
    }

    var body: some View {
        Toggle(isOn: $isEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                if nativeAppPresence.isInstalled(providerID) {
                    Text("App installiert")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
            .onChange(of: isEnabled) { _, _ in
                ProviderEnabledChange.notify()
            }
            .disabled(isSyncingThisProvider)
            .accessibilityHint(
                Text(
                    isEnabled
                        ? "Deaktivieren blendet das Portal unter Sync aus."
                        : "Aktivieren zeigt das Portal unter Sync an."
                )
            )
    }
}
