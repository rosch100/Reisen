import Foundation
import ReisenDomain

/// PNR/Auftragsnummer aus Modell-Output: Labels, Initialen und Preise sind keine Codes.
public enum PasteImportConfirmationCode {
    public static func sanitize(_ raw: String?) -> String? {
        guard let text = NonEmpty.string(raw) else { return nil }
        if text.count < 3 { return nil }
        if isLabel(text) { return nil }
        if isThousandsPrice(text) { return nil }
        if isBareNumericTotal(text) { return nil }
        return text
    }

    private static func isLabel(_ text: String) -> Bool {
        let key = PasteImportTextTokens.normalize(text).filter(\.isLetter)
        return labels.contains(key)
    }

    private static let labels: Set<String> = [
        "bookingreference",
        "bookingref",
        "pnr",
        "auftragsnummer",
        "confirmationnumber",
        "confirmationcode",
        "reservierungsnummer",
        "reservationnumber",
        "buchungscode",
        "buchungsnummer",
        "bookingcode",
        "ticketnumber",
        "orderid",
    ]

    /// `25.200.000` / `8.400.000` — nicht Booking.com `6500.799.317` (erste Gruppe 4-stellig).
    private static func isThousandsPrice(_ text: String) -> Bool {
        let compact = text.filter { !$0.isWhitespace }
        return compact.wholeMatch(of: /\d{1,3}(\.\d{3})+/) != nil
    }

    /// `25200000` ohne Tausenderpunkte, aber mit angehängten Nullen wie ein Total.
    private static func isBareNumericTotal(_ text: String) -> Bool {
        text.allSatisfy(\.isNumber) && text.count >= 7 && text.hasSuffix("000")
    }
}
