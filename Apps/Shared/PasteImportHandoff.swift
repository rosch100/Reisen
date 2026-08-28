import Foundation
import ReisenDomain

/// Fehler der Übergabe zwischen Share-Extension und App.
enum PasteImportHandoffError: Error, Equatable, Sendable {
    /// Die App Group fehlt in den Entitlements oder ist nicht eingerichtet.
    case appGroupUnavailable
    /// Die Bytes passen nicht zur gemeldeten Art (z. B. Text ohne UTF-8).
    case unreadablePayload
}

/// Übergabe einer geteilten Quelle von der Share-Extension an die App über die App Group.
///
/// Die Extension schreibt `meta.json` und `payload.bin` und bittet das System, `reisen://paste-import`
/// zu öffnen. iOS erlaubt Share-Extensions den App-Start nicht garantiert; darum holt die App eine
/// liegengebliebene Übergabe beim nächsten Aktivieren nach. Der Konsum löscht beide Dateien.
enum PasteImportHandoff {
    static let appGroupIdentifier = "group.de.reisen.Reisen.pasteimport"
    static let urlScheme = "reisen"
    static let urlHost = "paste-import"

    static let url = URL(string: "\(urlScheme)://\(urlHost)")!

    private static let metaFileName = "meta.json"
    private static let payloadFileName = "payload.bin"

    /// Art der Bytes in `payload.bin`; die Extension kennt keine Modelltypen der App.
    struct Meta: Codable, Equatable, Sendable {
        enum Kind: String, Codable, Sendable {
            case text
            case image
            case pdf
        }

        let kind: Kind
    }

    static func isHandoff(_ url: URL) -> Bool {
        url.scheme?.lowercased() == urlScheme && url.host?.lowercased() == urlHost
    }

    static func write(_ source: PasteImportSource) throws {
        guard let container = containerURL() else { throw PasteImportHandoffError.appGroupUnavailable }
        let (kind, payload) = parts(of: source)
        // Erst `meta.json`: `payload.bin` ist der Auslöser und darf nie ohne Art dastehen.
        try JSONEncoder().encode(Meta(kind: kind))
            .write(to: container.appendingPathComponent(metaFileName), options: .atomic)
        try payload.write(to: container.appendingPathComponent(payloadFileName), options: .atomic)
    }

    /// Konsumiert eine liegende Übergabe.
    ///
    /// Der einzige Konsum-Pfad und damit idempotent: URL-Öffnen und Aktivieren können beide
    /// feuern, der zweite Aufruf findet nichts mehr. Eine fehlende App Group ist hier kein
    /// Verlust, sondern `.noPayload` — dort kann nie etwas gelegen haben, und die App aktiviert
    /// sich ständig ohne jede Übergabe. Erst ein bereitliegender Payload, der sich nicht mehr
    /// lesen lässt, ist `.lostPayload`. Ob daraus eine Meldung wird, entscheidet der
    /// `PasteImportHandoffCoordinator` anhand des Auslösers.
    static func consumePending() -> PasteImportHandoffOutcome {
        guard let container = containerURL() else { return .noPayload }
        let payloadURL = container.appendingPathComponent(payloadFileName)
        let metaURL = container.appendingPathComponent(metaFileName)
        guard FileManager.default.fileExists(atPath: payloadURL.path) else { return .noPayload }
        defer {
            try? FileManager.default.removeItem(at: payloadURL)
            try? FileManager.default.removeItem(at: metaURL)
        }
        do {
            let meta = try JSONDecoder().decode(Meta.self, from: try Data(contentsOf: metaURL))
            return .payload(try source(kind: meta.kind, payload: try Data(contentsOf: payloadURL)))
        } catch {
            return .lostPayload
        }
    }

    private static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private static func parts(of source: PasteImportSource) -> (Meta.Kind, Data) {
        switch source {
        case .text(let text):
            return (.text, Data(text.utf8))
        case .image(let data):
            return (.image, data)
        case .pdf(let data):
            return (.pdf, data)
        }
    }

    private static func source(kind: Meta.Kind, payload: Data) throws -> PasteImportSource {
        switch kind {
        case .text:
            guard let text = String(data: payload, encoding: .utf8) else {
                throw PasteImportHandoffError.unreadablePayload
            }
            return .text(text)
        case .image:
            return .image(payload)
        case .pdf:
            return .pdf(payload)
        }
    }
}
