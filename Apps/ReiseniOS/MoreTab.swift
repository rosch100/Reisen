import SwiftUI
import SwiftData

import ReisenAppCore
import ReisenSharedUI

struct MoreTab: View {
    let onResetLocalStores: () -> Void
    let onWipeCloudAndReset: () -> Void

    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            SettingsView(
                showsDataManagement: true,
                onResetLocalStores: {
                    statusMessage = "Stores werden zurückgesetzt…"
                    onResetLocalStores()
                },
                onWipeCloudAndReset: {
                    statusMessage = "iCloud-Daten werden geleert…"
                    onWipeCloudAndReset()
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
