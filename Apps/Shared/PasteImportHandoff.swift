import Darwin
import Foundation
import ReisenDomain

/// Fehler der Übergabe zwischen Share-Extension und App.
enum PasteImportHandoffError: Error, Equatable, Sendable {
    /// Die App Group fehlt in den Entitlements oder ist nicht eingerichtet.
    case appGroupUnavailable
    /// Die Bytes passen nicht zur gemeldeten Art (z. B. Text ohne UTF-8).
    case unreadablePayload
    /// Writer und Consumer konnten die Übergabe nicht exklusiv sperren.
    case lockUnavailable
}

/// Übergabe einer geteilten Quelle von der Share-Extension an die App über die App Group.
///
/// Die Extension schreibt `meta.json` und `payload.bin` und bittet das System, die Handoff-URL
/// zu öffnen. iOS erlaubt Share-Extensions den App-Start nicht garantiert; darum holt die App eine
/// liegengebliebene Übergabe beim nächsten Aktivieren nach. Der Konsum löscht beide Dateien.
///
/// Write und Consume laufen unter einem App-Group-`flock`, damit kein Prozess eine halb
/// geschriebene oder gemischte Meta/Payload-Übergabe sieht.
///
/// Store und Private: Konstanten in `PasteImportHandoffIdentity`, Auswahl per `REISEN_IOS_PRIVATE`.
enum PasteImportHandoff {
    #if REISEN_IOS_PRIVATE
    static let appGroupIdentifier = PasteImportHandoffIdentity.privateAppGroup
    static let urlScheme = PasteImportHandoffIdentity.privateURLScheme
    #else
    static let appGroupIdentifier = PasteImportHandoffIdentity.storeAppGroup
    static let urlScheme = PasteImportHandoffIdentity.storeURLScheme
    #endif
    static let urlHost = PasteImportHandoffIdentity.urlHost

    static let url = URL(string: "\(urlScheme)://\(urlHost)")!

    private static let metaFileName = "meta.json"
    private static let payloadFileName = "payload.bin"
    private static let lockFileName = "handoff.lock"

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
        try withExclusiveLock(in: container) {
            let payloadURL = container.appendingPathComponent(payloadFileName)
            let metaURL = container.appendingPathComponent(metaFileName)
            let (kind, payload) = parts(of: source)
            // Alte Übergabe unsichtbar machen, bevor neue Meta geschrieben wird — sonst droht
            // neue Meta + alte Payload. `payload.bin` ist der Auslöser und kommt zuletzt.
            try removeIfExists(payloadURL)
            try removeIfExists(metaURL)
            try JSONEncoder().encode(Meta(kind: kind))
                .write(to: metaURL, options: .atomic)
            try payload.write(to: payloadURL, options: .atomic)
        }
    }

    /// Konsumiert eine liegende Übergabe.
    ///
    /// Der einzige Konsum-Pfad und damit idempotent: URL-Öffnen und Aktivieren können beide
    /// feuern, der zweite Aufruf findet nichts mehr. Eine fehlende App Group ist hier kein
    /// Verlust, sondern `.noPayload`.
    ///
    /// Nach erfolgreichem Decode: `payload.bin` muss weg, bevor `.payload` zurückkommt
    /// (sonst Doppelstart). Scheitert nur das Meta-Löschen, bleibt die Quelle trotzdem gültig.
    /// Scheitert das Payload-Löschen, bleiben die Dateien für einen späteren Versuch.
    static func consumePending() -> PasteImportHandoffOutcome {
        guard let container = containerURL() else { return .noPayload }
        do {
            return try withExclusiveLock(in: container) {
                let payloadURL = container.appendingPathComponent(payloadFileName)
                let metaURL = container.appendingPathComponent(metaFileName)
                guard FileManager.default.fileExists(atPath: payloadURL.path) else {
                    return .noPayload
                }
                let source: PasteImportSource
                do {
                    let meta = try JSONDecoder().decode(
                        Meta.self,
                        from: try Data(contentsOf: metaURL)
                    )
                    source = try Self.source(
                        kind: meta.kind,
                        payload: try Data(contentsOf: payloadURL)
                    )
                } catch {
                    removeBestEffort(payloadURL)
                    removeBestEffort(metaURL)
                    return .lostPayload
                }
                do {
                    try removeIfExists(payloadURL)
                } catch {
                    return .lostPayload
                }
                removeBestEffort(metaURL)
                return .payload(source)
            }
        } catch {
            return .lostPayload
        }
    }

    private static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// Exklusives `flock` über Extension und Host — deckt die gesamte Remove/Write- bzw. Consume-Sequenz.
    private static func withExclusiveLock<T>(
        in container: URL,
        _ body: () throws -> T
    ) throws -> T {
        let lockURL = container.appendingPathComponent(lockFileName)
        if !FileManager.default.fileExists(atPath: lockURL.path) {
            guard FileManager.default.createFile(atPath: lockURL.path, contents: nil) else {
                throw PasteImportHandoffError.lockUnavailable
            }
        }
        let fd = open(lockURL.path, O_RDWR)
        guard fd >= 0 else { throw PasteImportHandoffError.lockUnavailable }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw PasteImportHandoffError.lockUnavailable }
        defer { _ = flock(fd, LOCK_UN) }
        return try body()
    }

    private static func removeIfExists(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static func removeBestEffort(_ url: URL) {
        try? removeIfExists(url)
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
