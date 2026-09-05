import SwiftUI

import ReisenAppCore
import ReisenDomain

/// Toggles für Buchungsportale. SSOT: `AppSettingsKeys.providerEnabledKey`.
public struct ProviderEnabledSettingsSection: View {
    @Environment(\.providerRegistry) private var providerRegistry
    @AppStorage(AppSettingsKeys.providerSetupDeferred) private var hideInitialProviderSetup = false

    public init() {}

    public var body: some View {
        if let registry = providerRegistry, !registry.syncProviderIDs.isEmpty {
            Section {
                Toggle(L10n.string(.settingsHideProviderSetup), isOn: $hideInitialProviderSetup)
                    .accessibilityIdentifier(UITestingIdentifiers.settingsHideProviderSetupToggle)
                    .onChange(of: hideInitialProviderSetup) { _, _ in
                        ProviderEnabledChange.notify()
                    }
                ForEach(registry.syncProviderIDs, id: \.self) { id in
                    ProviderEnabledToggle(
                        providerID: id,
                        displayName: id.displayName
                    )
                }
            } header: {
                Text(L10n.string(.settingsBookingPortals))
            } footer: {
                Text(L10n.string(.settingsHideProviderSetupFooter))
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
            wrappedValue: false,
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
                    Text(L10n.string(.settingsAppInstalled))
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
                        ? L10n.string(.providerDeactivateHelp)
                        : L10n.string(.providerActivateHelp)
                )
            )
    }
}
