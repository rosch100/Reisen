import Foundation

/// Zeichenbudget für Prompt-Material. SSOT gegen On-Device-Context-Overflow.
///
/// Instructions + Few-Shots belegen den Großteil; das Material muss darunter passen.
public enum PasteImportPromptBudget {
    /// Maximale Zeichen des Nutzer-Materials (PDF-Focus oder Paste-Text).
    public static let maxMaterialCharacters = 2_200

    /// Ergebnis einer Budget-Kürzung — `didClip` steuert den UI-Hinweis.
    public struct ClipResult: Equatable, Sendable {
        public var text: String
        public var didClip: Bool

        public init(text: String, didClip: Bool) {
            self.text = text
            self.didClip = didClip
        }
    }

    /// Kürzt Text auf das Budget. Buchungsähnliche Absätze zuerst; Schnitte an Zeilenenden.
    public static func clip(_ text: String) -> ClipResult {
        guard text.count > maxMaterialCharacters else {
            return ClipResult(text: text, didClip: false)
        }
        return ClipResult(text: clippedBody(text), didClip: true)
    }

    private static func clippedBody(_ text: String) -> String {
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var bookingParagraphs: [String] = []
        var otherParagraphs: [String] = []
        for paragraph in paragraphs {
            if PasteImportBookingText.looksLikeBooking(paragraph) {
                bookingParagraphs.append(paragraph)
            } else {
                otherParagraphs.append(paragraph)
            }
        }
        let ordered = bookingParagraphs + otherParagraphs
        var kept: [String] = []
        var used = 0
        for paragraph in ordered {
            let separator = kept.isEmpty ? 0 : 2
            let room = maxMaterialCharacters - used - separator
            guard room > 0 else { break }
            if paragraph.count <= room {
                kept.append(paragraph)
                used += paragraph.count + separator
                continue
            }
            if let slice = lineBoundedPrefix(paragraph, maxCharacters: room), !slice.isEmpty {
                kept.append(slice)
            }
            break
        }
        let joined = kept.joined(separator: "\n\n")
        if !joined.isEmpty { return joined }
        return lineBoundedPrefix(text, maxCharacters: maxMaterialCharacters)
            ?? String(text.prefix(maxMaterialCharacters))
    }

    /// Bevorzugt einen Schnitt nach dem letzten vollständigen Zeilenumbruch im Limit.
    private static func lineBoundedPrefix(_ text: String, maxCharacters: Int) -> String? {
        guard maxCharacters > 0 else { return nil }
        guard text.count > maxCharacters else { return text }
        let head = String(text.prefix(maxCharacters))
        if let lastNewline = head.lastIndex(of: "\n"), lastNewline > head.startIndex {
            let sliced = String(head[..<lastNewline])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return sliced.isEmpty ? nil : sliced
        }
        let trimmed = head.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
