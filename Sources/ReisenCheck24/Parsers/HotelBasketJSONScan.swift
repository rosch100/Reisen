import Foundation

/// Brace-aware scan of a top-level JSON object following a key in HTML/JS payloads.
enum HotelBasketJSONScan {
    /// Extracts the JSON object that immediately follows a key occurrence.
    /// Example: when `after` is `"basketDetails"`, this returns the surrounding `{ ... }`.
    static func extractTopLevelJSONObject(from text: String, after key: String) -> String? {
        guard let keyRange = text.range(of: key) else { return nil }

        // Find the first '{' after the key.
        let searchStart = text.index(keyRange.upperBound, offsetBy: 0)
        guard let openBraceIndex = text[searchStart...].firstIndex(of: "{") else { return nil }

        guard let jsonRange = scanTopLevelJSONObjectRange(
            text: text,
            openBraceIndex: openBraceIndex
        ) else { return nil }

        return String(text[jsonRange])
    }
}
