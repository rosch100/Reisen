import Foundation

/// Zeichenbudget für Prompt-Material. SSOT gegen On-Device-Context-Overflow.
///
/// Instructions + Few-Shots belegen den Großteil; das Material muss darunter passen.
public enum PasteImportPromptBudget {
    /// Maximale Zeichen des Nutzer-Materials (PDF-Focus oder Paste-Text).
    public static let maxMaterialCharacters = 2_200

    /// Kürzt Text auf das Budget. Buchungsähnliche Absätze (getrennt durch Leerzeilen) zuerst.
    public static func clipped(_ text: String) -> String {
        guard text.count > maxMaterialCharacters else { return text }
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let bookingFirst = paragraphs.filter(looksLikeBooking) + paragraphs.filter { !looksLikeBooking($0) }
        var kept: [String] = []
        var used = 0
        for paragraph in bookingFirst {
            let separator = kept.isEmpty ? 0 : 2
            let room = maxMaterialCharacters - used - separator
            guard room > 0 else { break }
            if paragraph.count <= room {
                kept.append(paragraph)
                used += paragraph.count + separator
            } else {
                kept.append(String(paragraph.prefix(room)))
                break
            }
        }
        let joined = kept.joined(separator: "\n\n")
        if !joined.isEmpty { return joined }
        return String(text.prefix(maxMaterialCharacters))
    }

    private static let bookingNeedles = [
        "pnr",
        "booking reference",
        "booking confirmation",
        "passenger",
        "itinerary",
        "departure",
        "check-in",
        "check in",
        "reservation",
        "auftragsnummer",
        "buchungscode",
        "e-ticket",
        "eticket",
        "abfahrt",
        "confirmation number",
        "reservierungsnummer",
        "reiseverlauf",
        "boarding",
        "flug",
        "flight",
    ]

    private static func looksLikeBooking(_ paragraph: String) -> Bool {
        let hay = paragraph.lowercased()
        return bookingNeedles.contains { hay.contains($0) }
    }
}
