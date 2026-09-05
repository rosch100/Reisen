import SwiftUI

struct AppMenuCommandState {
    var canSyncAll: Bool
    /// Edit Trip und Neue Buchung — dieselbe Single-Trip-Gate.
    var canPerformSingleTripActions: Bool
    var canAssignBookings: Bool
}

private struct AppMenuCommandStateKey: FocusedValueKey {
    typealias Value = AppMenuCommandState
}

/// Von `SyncView` gesetzt — Menü „Aktuelles Portal aktualisieren“ = Toolbar-`canSync`.
private struct ProviderSyncCanSyncKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    var appMenuCommandState: AppMenuCommandState? {
        get { self[AppMenuCommandStateKey.self] }
        set { self[AppMenuCommandStateKey.self] = newValue }
    }

    var providerSyncCanSync: Bool? {
        get { self[ProviderSyncCanSyncKey.self] }
        set { self[ProviderSyncCanSyncKey.self] = newValue }
    }
}

extension View {
    /// HIG/Plan: Enabled-Help entfällt; nur Disabled-Grund als `.help`.
    @ViewBuilder
    func menuDisabledOnlyHelp(isEnabled: Bool, disabledHelp: String) -> some View {
        if isEnabled {
            self
        } else {
            self.help(disabledHelp)
        }
    }

    func menuEnableHelp(isEnabled: Bool, enabledHelp: String, disabledHelp: String) -> some View {
        help(isEnabled ? enabledHelp : disabledHelp)
    }
}
