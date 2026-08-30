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
    private var windowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let icon = NSImage(named: "AppIcon") ?? loadBundledAppIcon() {
            NSApp.applicationIconImage = icon
        }
        NSApp.activate(ignoringOtherApps: true)
        if UITestingLaunch.isActive {
            placeWindowsOnPrimaryScreen(NSApp.windows)
        }

        // macOS 26+: SwiftUI-WindowGroup nutzt oft fullSizeContentView.
        // Dann landet Sidebar-/Detail-Inhalt unter der Titlebar (Traffic-Lights-Overlap)
        // und die Action-Bar wird unten abgeschnitten — besonders mit WKWebView.
        normalizeTitlebar(for: NSApp.windows)
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let window = note.object as? NSWindow else { return }
            Task { @MainActor in
                self?.normalizeTitlebar(for: [window])
                if UITestingLaunch.isActive {
                    self?.placeWindowsOnPrimaryScreen([window])
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let windowObserver {
            NotificationCenter.default.removeObserver(windowObserver)
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Dock- und Finder-Drop („Öffnen mit“) — dieselben Typen wie der Dateidialog.
    func application(_ application: NSApplication, open urls: [URL]) {
        PasteImportExternalFileInbox.offer(urls)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func loadBundledAppIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            return NSImage(contentsOf: url)
        }
        // Zusätzlicher Pfad für Bundle-Layouts ohne Image-Asset-Katalog.
        let exe = URL(fileURLWithPath: Bundle.main.executablePath ?? CommandLine.arguments[0])
        let resources = exe.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
        let icns = resources.appendingPathComponent("AppIcon.icns")
        return NSImage(contentsOf: icns)
    }
}
