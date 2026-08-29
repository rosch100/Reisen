import Foundation

/// Needle-Listen für „sieht nach Buchung aus“ vs. AGB — SSOT für PDF-Focus und Prompt-Budget.
enum PasteImportBookingText {
    static let bookingNeedles = [
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

    static let boilerplateNeedles = [
        "fare rules",
        "important notes",
        "catatan penting",
        "free baggage allowance",
        "terms and condition",
        "terms & conditions",
        "term and condition",
        "dilarang memasukkan",
        "wheelchair services",
        "baggage weight rounding",
    ]

    static func looksLikeBooking(_ text: String) -> Bool {
        contains(needles: bookingNeedles, in: text)
    }

    static func isBoilerplate(_ text: String) -> Bool {
        contains(needles: boilerplateNeedles, in: text)
    }

    private static func contains(needles: [String], in text: String) -> Bool {
        let hay = text.lowercased()
        return needles.contains { hay.contains($0) }
    }
}
