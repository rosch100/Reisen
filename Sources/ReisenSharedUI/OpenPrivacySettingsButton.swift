import SwiftUI
import ReisenDomain

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Öffnet das passende Datenschutz-Pane in den System-/App-Einstellungen.
public enum PrivacySettingsOpener {
    @MainActor
    public static func open(_ pane: PrivacySettingPane) {
        #if os(iOS)
        openIOS(pane)
        #elseif os(macOS)
        openMacOS(pane)
        #endif
    }

    #if os(iOS)
    private static func openIOS(_ pane: PrivacySettingPane) {
        let raw: String
        switch pane {
        case .notifications:
            raw = UIApplication.openNotificationSettingsURLString
        case .calendars, .reminders:
            raw = UIApplication.openSettingsURLString
        }
        guard let url = URL(string: raw) else { return }
        UIApplication.shared.open(url)
    }
    #endif

    #if os(macOS)
    private static func openMacOS(_ pane: PrivacySettingPane) {
        let candidates = PrivacySettingsURL.macOSCandidates(
            for: pane,
            bundleIdentifier: Bundle.main.bundleIdentifier
        )
        for url in candidates where NSWorkspace.shared.open(url) {
            return
        }
    }
    #endif
}

public struct OpenPrivacySettingsButton: View {
    let pane: PrivacySettingPane

    public init(pane: PrivacySettingPane) {
        self.pane = pane
    }

    public var body: some View {
        Button {
            PrivacySettingsOpener.open(pane)
        } label: {
            Label(pane.openButtonTitle, systemImage: "gear")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
}
