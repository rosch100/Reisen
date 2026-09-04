import SwiftUI
import SwiftData

import ReisenAppCore
import ReisenSharedUI

struct MoreTab: View {
    let onResetLocalStores: () -> Void
    let onWipeCloudAndReset: () -> Void
    let onApplyICloudSyncPreference: (Bool, Bool) -> Void

    @State private var statusMessage: String?

    /// Store-Target setzt `REISEN_PROVIDER_SYNC` nicht — SettingsView blendet Provider-Sync aus.
    private var showsProviderSyncSettings: Bool {
        #if REISEN_PROVIDER_SYNC
        true
        #else
        false
        #endif
    }

    var body: some View {
        NavigationStack {
            SettingsView(
                showsProviderSyncSettings: showsProviderSyncSettings,
                showsDataManagement: true,
                onResetLocalStores: {
                    statusMessage = "Stores werden zurückgesetzt…"
                    onResetLocalStores()
                },
                onWipeCloudAndReset: {
                    statusMessage = "iCloud-Daten werden geleert…"
                    onWipeCloudAndReset()
                },
                onApplyICloudSyncPreference: { enabled, wipe in
                    statusMessage = enabled
                        ? "iCloud-Sync wird eingeschaltet…"
                        : (wipe ? "iCloud-Sync wird gestoppt und geleert…" : "iCloud-Sync wird gestoppt…")
                    onApplyICloudSyncPreference(enabled, wipe)
                }
            )
            .navigationTitle("Mehr")
            .safeAreaInset(edge: .bottom) {
                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.bar)
                }
            }
        }
    }
}
