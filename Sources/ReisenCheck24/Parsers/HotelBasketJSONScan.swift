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

    /// Innermost JSON-Objekt, das `containingKey` enthält (z. B. `"mealType"` im Rate-/Offer-Blob).
    static func extractEnclosingJSONObject(from text: String, containingKey key: String) -> String? {
        guard let keyRange = text.range(of: key),
              let openBraceIndex = openingBraceIndex(before: keyRange.lowerBound, in: text),
              let jsonRange = scanTopLevelJSONObjectRange(
                text: text,
                openBraceIndex: openBraceIndex
              )
        else {
            return nil
        }
        return String(text[jsonRange])
    }

    /// Letztes noch offenes `{` vor `index` (String-Literale werden übersprungen).
    private static func openingBraceIndex(before index: String.Index, in text: String) -> String.Index? {
        var stack: [String.Index] = []
        var i = text.startIndex
        var inString = false
        var isEscaped = false
        while i < index {
            let ch = text[i]
            if inString {
                updateStringState(ch: ch, inString: &inString, isEscaped: &isEscaped)
            } else if ch == "\"" {
                inString = true
            } else if ch == "{" {
                stack.append(i)
            } else if ch == "}", !stack.isEmpty {
                stack.removeLast()
            }
            i = text.index(after: i)
        }
        return stack.last
    }
}
