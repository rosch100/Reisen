import SwiftUI
import ReisenDomain

/// Beschriftung und Zustand des Paste-Import-Einstiegs.
///
/// Ohne verfügbares Modell bleibt die Aktion sichtbar, aber deaktiviert — mit der Begründung
/// im Accessibility-Label, damit der Grund nicht nur als ausgegrautes Steuerelement erscheint.
public struct PasteImportActionPresentation: Equatable, Sendable {
    public let label: String
    public let isEnabled: Bool
    public let disabledReason: String?

    public var accessibilityLabel: String {
        guard let disabledReason else { return label }
        return "\(label) \(disabledReason)"
    }

    public init(kind: PasteImportModelKind) {
        label = L10n.string(.menuPasteBooking)
        isEnabled = kind != .unavailable
        disabledReason = kind == .unavailable ? L10n.string(.pasteImportUnavailable) : nil
    }
}

/// Menü-/Toolbar-Button „Buchung einfügen…“.
public struct PasteImportActionControl: View {
    private let kind: PasteImportModelKind
    private let action: () -> Void

    public init(kind: PasteImportModelKind, action: @escaping () -> Void) {
        self.kind = kind
        self.action = action
    }

    public var body: some View {
        let presentation = PasteImportActionPresentation(kind: kind)

        Button(presentation.label, systemImage: "doc.on.clipboard", action: action)
            .disabled(!presentation.isEnabled)
            .accessibilityLabel(Text(presentation.accessibilityLabel))
            .help(presentation.accessibilityLabel)
    }
}
