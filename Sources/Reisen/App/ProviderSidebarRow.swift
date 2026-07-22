import SwiftUI
import AppKit
import ReisenDomain

struct ProviderSidebarRow: View {
    let providerID: ProviderID

    @Environment(\.syncStore) private var store
    @Environment(\.providerSessionHub) private var sessionHub
    @AppStorage private var isEnabled: Bool

    init(providerID: ProviderID) {
        self.providerID = providerID
        self._isEnabled = AppStorage(
            wrappedValue: true,
            AppSettingsKeys.providerEnabledKey(for: providerID)
        )
    }

    private var providerDisplayName: String {
        switch providerID {
        case .check24: return "Check24"
        case .opodo: return "Opodo"
        case .booking: return "Booking.com"
        case .airbnb: return "Airbnb"
        default: return providerID.rawValue.capitalized
        }
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

    private var trafficLightColor: Color {
        switch trafficLight {
        case .green: return .green
        case .red: return .red
        case .gray: return Color(nsColor: .tertiaryLabelColor)
        }
    }

    private var trafficLightAccessibilityLabel: String {
        switch trafficLight {
        case .green: return "Angemeldet"
        case .red: return "Anmeldung erforderlich"
        case .gray: return "Provider deaktiviert"
        }
    }

    var body: some View {
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

            if isSyncingThisProvider {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(Text("Synchronisiere \(providerDisplayName)"))
            }
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
