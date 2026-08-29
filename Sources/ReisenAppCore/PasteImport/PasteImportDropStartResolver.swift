import Foundation
import ReisenDomain

/// Ergebnis der Datei-Auflösung für Drop / „Öffnen mit“.
public enum PasteImportDropStart: Equatable, Sendable {
    case ignore
    case fail(String)
    case source(PasteImportSource)

    public func apply(
        onFail: (String) -> Void,
        onSource: (PasteImportSource) -> Void
    ) {
        switch self {
        case .ignore:
            break
        case .fail(let message):
            onFail(message)
        case .source(let source):
            onSource(source)
        }
    }
}

/// Gemeinsame Auflösung von Drop-/Dock-/Inbox-URLs zu Quelle oder Fehlertext.
///
/// Ein laufender Import oder eine offene Editor-Warteschlange darf nicht durch einen zweiten
/// Datei-Einstieg überschrieben werden — anders als Toolbar/Menü, die bewusst neu starten.
public enum PasteImportDropStartResolver {
    /// Reine Zähl-Entscheidung ohne Datei-I/O.
    public enum Decision: Equatable, Sendable {
        case ignore
        case fail
        case start
    }

    /// - Parameters:
    ///   - offeredURLCount: Anzahl der angelieferten URLs (auch ungeeignete).
    ///   - acceptedFileCount: Anzahl der URLs, die als Paste-Import-Quelle gelten.
    ///   - isSessionActive: Lauf, Meldung oder Editor-Warteschlange ist offen.
    public static func decision(
        offeredURLCount: Int,
        acceptedFileCount: Int,
        isSessionActive: Bool
    ) -> Decision {
        guard offeredURLCount > 0 else { return .ignore }
        if isSessionActive { return .ignore }
        if acceptedFileCount > 0 { return .start }
        return .fail
    }

    public static func resolve(urls: [URL], isSessionActive: Bool) -> PasteImportDropStart {
        let files = PasteImportFileSource.acceptedFiles(in: urls)
        switch decision(
            offeredURLCount: urls.count,
            acceptedFileCount: files.count,
            isSessionActive: isSessionActive
        ) {
        case .ignore:
            return .ignore
        case .fail:
            return sourceFailure
        case .start:
            guard let url = files.first else {
                return sourceFailure
            }
            do {
                return .source(try PasteImportFileSource.source(from: url))
            } catch {
                return .fail(PasteImportFailureMessage.text(for: error))
            }
        }
    }

    private static var sourceFailure: PasteImportDropStart {
        .fail(L10n.string(.pasteImportErrorSource))
    }

    /// Holt Inbox-URLs und löst sie auf. Bei `.ignore` kommen die URLs wieder vorne in die Inbox.
    @MainActor
    public static func consumeInbox(isSessionActive: Bool) -> PasteImportDropStart {
        let urls = PasteImportExternalFileInbox.take()
        guard !urls.isEmpty else { return .ignore }
        let start = resolve(urls: urls, isSessionActive: isSessionActive)
        if case .ignore = start {
            PasteImportExternalFileInbox.restore(urls)
        }
        return start
    }

    /// Zurückgelegte Inbox-URLs erneut versuchen, sobald die Session wieder idle ist.
    public static func shouldRetryInbox(wasActive: Bool, isActive: Bool) -> Bool {
        wasActive && !isActive
    }
}
