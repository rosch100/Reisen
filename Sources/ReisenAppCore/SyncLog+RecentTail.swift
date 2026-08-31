import Foundation
import ReisenDiagnostics

extension SyncLog {
    static func recentTail(
        maxBytes: Int = DiagnosticLogAttachment.attachMaxRawBytes,
        fileURL: URL? = nil,
        includeLocalDebug: Bool = false
    ) -> DiagnosticLogAttachment {
        guard let url = fileURL ?? Self.fileURL() else { return .missing }
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return .missing }
        do {
            let data = try Data(contentsOf: url)
            if data.isEmpty { return .empty }
            let fileByteCount = data.count
            let truncated = fileByteCount > maxBytes
            let rawTail = dropPartialLeadingLine(
                from: String(decoding: data.suffix(maxBytes), as: UTF8.self),
                truncated: truncated
            )
            let tail = includeLocalDebug ? rawTail : exportableTail(from: rawTail)
            let redacted = SecretRedactor.redact(tail)
            return DiagnosticLogAttachment.makeAttached(
                redactedTail: redacted,
                fileByteCount: fileByteCount,
                truncated: truncated
            )
        } catch {
            return .unreadable(error.localizedDescription)
        }
    }

    /// Bei Byte-Truncation erste (unvollständige) Zeile verwerfen.
    /// Ohne Newline ist das gesamte Suffix eine Teilzeile → leer.
    private static func dropPartialLeadingLine(from rawTail: String, truncated: Bool) -> String {
        guard truncated else { return rawTail }
        guard let newline = rawTail.firstIndex(of: "\n") else { return "" }
        return String(rawTail[rawTail.index(after: newline)...])
    }

    private static func exportableTail(from tail: String) -> String {
        tail.split(separator: "\n", omittingEmptySubsequences: false)
            .filter(isExportableLine)
            .joined(separator: "\n")
    }

    private static func isExportableLine(_ line: Substring) -> Bool {
        guard let markerRange = line.range(of: "diagnostic=") else { return true }
        let payload = line[markerRange.upperBound...]
        guard let data = payload.data(using: .utf8),
              let event = try? JSONDecoder().decode(DiagnosticEvent.self, from: data)
        else {
            return false
        }
        return event.visibility == .publicDiagnostic
    }
}
