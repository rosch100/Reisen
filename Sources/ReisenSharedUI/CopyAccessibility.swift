import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
import ReisenDomain

enum CopyAccessibility {
    /// Schreibt Plain-Text und kündigt „Kopiert“ an (leerer String: no-op).
    @MainActor
    static func copy(_ string: String, using pasteboard: StringPasteboardClient) {
        guard !string.isEmpty else { return }
        pasteboard.copy(string)
        announceCopied()
    }

    @MainActor
    private static func announceCopied() {
        let message = L10n.string(.commonCopied)
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #elseif os(macOS)
        let element: Any
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            element = window
        } else if let app = NSApp {
            element = app
        } else {
            return
        }
        NSAccessibility.post(
            element: element,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ]
        )
        #endif
    }
}
