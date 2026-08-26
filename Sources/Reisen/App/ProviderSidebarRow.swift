import SwiftUI
import AppKit
import ReisenDomain
import ReisenAppCore
import ReisenSharedUI

struct ProviderSidebarRow: View {
    let providerID: ProviderID

    @Environment(\.syncStore) private var store
    @Environment(\.providerSessionHub) private var sessionHub
    @Environment(\.providerRegistry) private var providerRegistry
    @AppStorage private var isEnabled: Bool

    init(providerID: ProviderID) {
        self.providerID = providerID
        self._isEnabled = AppStorage(
            wrappedValue: true,
            AppSettingsKeys.providerEnabledKey(for: providerID)
        )
    }

    private var providerDisplayName: String {
        providerRegistry?.provider(id: providerID)?.displayName ?? providerID.displayName
    }

    private var isSyncingThisProvider: Bool {
        store?.syncingProviderID == providerID && store?.isSyncing == true
    }

    private var trafficLight: ProviderLoginTrafficLight {
        ProviderLoginTrafficLight.resolve(
            isEnabled: isEnabled,
            isLoggedIn: sessionHub?.isLoggedIn(for: providerID)
        )
    }

    private var trafficLightColor: Color { trafficLight.color }

    private var trafficLightAccessibilityLabel: String { trafficLight.displayLabel }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                ProviderLogo(providerID: providerID)

                Text(providerDisplayName)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Circle()
                    .fill(trafficLightColor)
                    .frame(width: 9, height: 9)
                    .accessibilityLabel(Text(trafficLightAccessibilityLabel))
                    .help(trafficLightAccessibilityLabel)

                if isSyncingThisProvider {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(Text("Synchronisiere \(providerDisplayName)"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(Text(providerDisplayName))

            Button {
                isEnabled.toggle()
            } label: {
                Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .disabled(isSyncingThisProvider)
            .accessibilityLabel(Text(
                isEnabled
                    ? "\(providerDisplayName) deaktivieren"
                    : "\(providerDisplayName) aktivieren"
            ))
            .accessibilityAddTraits(isEnabled ? .isSelected : [])
            .help(isEnabled ? "Provider deaktivieren" : "Provider aktivieren")
        }
        .contextMenu {
            Button(isEnabled ? "Deaktivieren" : "Aktivieren") {
                isEnabled.toggle()
            }
            .disabled(isSyncingThisProvider)

            Button("Sync öffnen") {
                NotificationCenter.default.post(
                    name: .reisenShowProviderSync,
                    object: providerID
                )
            }
        }
    }
}
