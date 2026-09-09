import Foundation

/// Live-belegte Hotel-Storno-URL: `confirmation*.html` → `cancel*.html`, `auth_key` behalten.
enum BookingComCancellationURL {
    private static let confirmationPathPattern =
        #"confirmation((?:\.[A-Za-z]{2}(?:-[A-Za-z]{2})?)?\.html)"#
    private static let authKeyPattern = #"(?i)(?:^|[?;&])auth_key="#

    /// Baut Cancel-URL aus Confirmation-/Booking-URL. Ohne `auth_key` oder Confirmation-Pfad → `nil`.
    static func fromConfirmationURL(_ externalUrl: String) -> String? {
        guard let absolute = BookingComParsing.absoluteBookingURL(externalUrl) else { return nil }
        guard absolute.range(of: authKeyPattern, options: .regularExpression) != nil else {
            return nil
        }
        guard let regex = try? NSRegularExpression(
            pattern: confirmationPathPattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }
        let range = NSRange(absolute.startIndex..<absolute.endIndex, in: absolute)
        guard regex.firstMatch(in: absolute, options: [], range: range) != nil else {
            return nil
        }
        let replaced = regex.stringByReplacingMatches(
            in: absolute,
            options: [],
            range: range,
            withTemplate: "cancel$1"
        )
        return replaced == absolute ? nil : replaced
    }
}
