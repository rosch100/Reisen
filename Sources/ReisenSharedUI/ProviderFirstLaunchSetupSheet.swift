import SwiftUI

import ReisenAppCore
import ReisenDomain

/// HIG First-Launch-Sheet zur Auswahl der Sync-Buchungsportale (macOS + iOS).
///
/// Persistenz/Notify liegen beim Host (`onContinue` / `onLater`); dieses View hält nur die Auswahl-UI.
public struct ProviderFirstLaunchSetupSheet: View {
    private let syncProviderIDsOverride: [ProviderID]?
    private let onContinue: (Set<ProviderID>) -> Void
    private let onLater: () -> Void
    private let externalSelection: Binding<Set<ProviderID>>?

    @Environment(\.providerRegistry) private var providerRegistry
    @Environment(\.providerNativeAppPresence) private var nativeAppPresence

    @State private var ownedSelection: Set<ProviderID>

    public init(
        syncProviderIDs: [ProviderID]? = nil,
        selection: Binding<Set<ProviderID>>,
        onContinue: @escaping (Set<ProviderID>) -> Void,
        onLater: @escaping () -> Void
    ) {
        self.syncProviderIDsOverride = syncProviderIDs
        self.externalSelection = selection
        self._ownedSelection = State(initialValue: selection.wrappedValue)
        self.onContinue = onContinue
        self.onLater = onLater
    }

    public init(
        syncProviderIDs: [ProviderID]? = nil,
        initialSelection: Set<ProviderID> = [],
        onContinue: @escaping (Set<ProviderID>) -> Void,
        onLater: @escaping () -> Void
    ) {
        self.syncProviderIDsOverride = syncProviderIDs
        self.externalSelection = nil
        self._ownedSelection = State(initialValue: initialSelection)
        self.onContinue = onContinue
        self.onLater = onLater
    }

    private var selection: Binding<Set<ProviderID>> {
        externalSelection ?? $ownedSelection
    }

    private var syncProviderIDs: [ProviderID] {
        if let syncProviderIDsOverride {
            return syncProviderIDsOverride
        }
        if let registry = providerRegistry {
            return registry.syncProviderIDs
        }
        return ProviderID.syncProviderIDs
    }

    private var canContinue: Bool {
        !selection.wrappedValue.isEmpty
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            providerList
            Divider()
            footer
        }
#if os(macOS)
        .frame(minWidth: 420, idealWidth: 460, minHeight: 360)
        .presentationSizing(.fitted)
#else
        .presentationDragIndicator(.visible)
        .reisenSheetDetents()
#endif
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(UITestingIdentifiers.providerSetupSheet)
        .accessibilityLabel(L10n.string(.setupProvidersTitle))
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(L10n.string(.setupProvidersTitle))
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(L10n.string(.setupProvidersSubtitle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var providerList: some View {
        Form {
            ForEach(syncProviderIDs, id: \.self) { providerID in
                Toggle(isOn: binding(for: providerID)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(providerID.displayName)
                        if nativeAppPresence.isInstalled(providerID) {
                            Text(L10n.string(.settingsAppInstalled))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityIdentifier(UITestingIdentifiers.providerSetupToggle(providerID))
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 8)
    }

    private var footer: some View {
        HStack {
            Button(L10n.string(.setupProvidersLater)) {
                onLater()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier(UITestingIdentifiers.providerSetupLater)

            Spacer()

            Button(L10n.string(.setupProvidersContinue)) {
                onContinue(selection.wrappedValue)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canContinue)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier(UITestingIdentifiers.providerSetupContinue)
        }
        .padding(16)
    }

    private func binding(for providerID: ProviderID) -> Binding<Bool> {
        Binding(
            get: { selection.wrappedValue.contains(providerID) },
            set: { isOn in
                var next = selection.wrappedValue
                if isOn {
                    next.insert(providerID)
                } else {
                    next.remove(providerID)
                }
                selection.wrappedValue = next
            }
        )
    }
}
