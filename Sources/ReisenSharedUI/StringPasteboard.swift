import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Plain-Text-Schreibzugriff auf die System-Zwischenablage (SSOT).
@MainActor
public protocol StringPasteboard: AnyObject {
    /// Leerer String: Pasteboard unverändert lassen.
    func copy(_ string: String)
}

@MainActor
public final class SystemStringPasteboard: StringPasteboard {
    public static let shared = SystemStringPasteboard()

    private init() {}

    public func copy(_ string: String) {
        guard !string.isEmpty else { return }
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        #endif
    }
}

/// Environment-tauglicher Pasteboard-Client (Sendable Closure; Aufruf auf MainActor).
public struct StringPasteboardClient: Sendable {
    private let _copy: @Sendable @MainActor (String) -> Void

    public init(copy: @escaping @Sendable @MainActor (String) -> Void) {
        self._copy = copy
    }

    @MainActor
    public func copy(_ string: String) {
        _copy(string)
    }

    public static let system = StringPasteboardClient { string in
        SystemStringPasteboard.shared.copy(string)
    }

    @MainActor
    public static func spy(_ pasteboard: any StringPasteboard) -> StringPasteboardClient {
        StringPasteboardClient { string in
            pasteboard.copy(string)
        }
    }
}

private struct StringPasteboardKey: EnvironmentKey {
    static let defaultValue = StringPasteboardClient.system
}

public extension EnvironmentValues {
    var stringPasteboard: StringPasteboardClient {
        get { self[StringPasteboardKey.self] }
        set { self[StringPasteboardKey.self] = newValue }
    }
}
