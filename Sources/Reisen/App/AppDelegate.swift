import Foundation
import AppKit
import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData
import ReisenAppCore

/// Stellt sicher, dass die SwiftPM-Executable als normale GUI-App mit Dock-Icon läuft.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notificationObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // Dock/Finder-Icon nur über CFBundleIconFile (AppIcon.icns).
        // Ein manuelles Setzen des Application-Icons als Bitmap umgeht die System-Squircle-Maske.
        NSApp.activate(ignoringOtherApps: true)
        if UITestingLaunch.isActive {
            placeWindowsOnPrimaryScreen(NSApp.windows)
        }

        // macOS 26+: SwiftUI-WindowGroup nutzt oft fullSizeContentView.
        // Dann landet Sidebar-/Detail-Inhalt unter der Titlebar (Traffic-Lights-Overlap)
        // und die Action-Bar wird unten abgeschnitten — besonders mit WKWebView.
        normalizeTitlebar(for: NSApp.windows)
        disableWindowRestorationForQuit(NSApp.windows)
        MacAppQuitSheetDismissal.allowApplicationTerminationWhileModal(in: NSApp.windows)
        observeQuitRelevantWindowNotifications()
        installQuitAppleEventHandler()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        disableWindowRestorationForQuit(sender.windows)
        MacAppQuitSheetDismissal.prepareForTermination(in: sender)
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEQuitApplication)
        )
    }

    private func observeQuitRelevantWindowNotifications() {
        let center = NotificationCenter.default
        notificationObservers.append(center.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let window = note.object as? NSWindow else { return }
            Task { @MainActor in
                self?.normalizeTitlebar(for: [window])
                self?.disableWindowRestorationForQuit([window])
                MacAppQuitSheetDismissal.allowApplicationTerminationWhileModal(in: NSApp.windows)
                if UITestingLaunch.isActive {
                    self?.placeWindowsOnPrimaryScreen([window])
                }
            }
        })
        // willBegin feuert vor attachedSheet — ein Runloop-Tick nachziehen (kein Polling).
        notificationObservers.append(center.addObserver(
            forName: NSWindow.willBeginSheetNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await Task.yield()
                MacAppQuitSheetDismissal.allowApplicationTerminationWhileModal(in: NSApp.windows)
            }
        })
    }

    private func installQuitAppleEventHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleQuitAppleEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEQuitApplication)
        )
    }

    /// Dock/AppleScript-Quit: Sheets zuerst freigeben, sonst blockiert AppKit vor dem Delegate.
    @objc private func handleQuitAppleEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        MacAppQuitSheetDismissal.prepareForTermination(in: NSApp)
        DispatchQueue.main.async {
            MacAppQuitSheetDismissal.allowApplicationTerminationWhileModal(in: NSApp.windows)
            NSApp.terminate(nil)
        }
    }

    /// XCUI-Audit und Klicks brauchen ein Fenster auf dem Haupt-Display (nicht y < 0).
    private func placeWindowsOnPrimaryScreen(_ windows: [NSWindow]) {
        guard let screen = NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        for window in windows where window.styleMask.contains(.titled) {
            var frame = window.frame
            frame.origin.x = visible.minX + 60
            frame.origin.y = visible.minY + 60
            if frame.maxX > visible.maxX {
                frame.origin.x = max(visible.minX, visible.maxX - frame.width)
            }
            if frame.maxY > visible.maxY {
                frame.origin.y = max(visible.minY, visible.maxY - frame.height)
            }
            window.setFrame(frame, display: true)
        }
    }

    private func normalizeTitlebar(for windows: [NSWindow]) {
        for window in windows where window.styleMask.contains(.titled) {
            if window.styleMask.contains(.fullSizeContentView) {
                window.styleMask.remove(.fullSizeContentView)
            }
            window.titlebarAppearsTransparent = false
        }
    }

    /// Verhindert synchronen AppKit-State-Restoration-Flush (Runloop-Spin) mit WKWebViews beim Quit.
    private func disableWindowRestorationForQuit(_ windows: [NSWindow]) {
        for window in windows {
            window.isRestorable = false
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Dock- und Finder-Drop („Öffnen mit“) — dieselben Typen wie der Dateidialog.
    func application(_ application: NSApplication, open urls: [URL]) {
        PasteImportExternalFileInbox.offer(urls)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// SSOT: Modal-Sheets dürfen Quit nicht blockieren; optional endSheet beim Terminate.
enum MacAppQuitSheetDismissal {
    @MainActor
    static func allowApplicationTerminationWhileModal(in windows: [NSWindow]) {
        for window in windows {
            window.preventsApplicationTerminationWhenModal = false
            if let sheet = window.attachedSheet {
                sheet.preventsApplicationTerminationWhenModal = false
            }
            for sheet in window.sheets {
                sheet.preventsApplicationTerminationWhenModal = false
            }
        }
        if let modalWindow = NSApp.modalWindow {
            modalWindow.preventsApplicationTerminationWhenModal = false
        }
    }

    @MainActor
    static func prepareForTermination(in app: NSApplication) {
        allowApplicationTerminationWhileModal(in: app.windows)
        if app.modalWindow != nil {
            app.abortModal()
        }
        _ = dismissBlockingSheets(in: app)
    }

    /// - Returns: `true` wenn mindestens ein Sheet geschlossen wurde.
    @MainActor
    static func dismissBlockingSheets(in app: NSApplication) -> Bool {
        var dismissed = false
        for window in app.windows {
            if let sheet = window.attachedSheet {
                window.endSheet(sheet, returnCode: .abort)
                dismissed = true
            }
            for sheet in window.sheets where sheet !== window.attachedSheet {
                window.endSheet(sheet, returnCode: .abort)
                dismissed = true
            }
        }
        return dismissed
    }
}
