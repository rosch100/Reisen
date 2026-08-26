import Foundation

/// Extrahiert `window.__INITIAL_STATE__ = {…}` aus HTML (Brace-Scan, kein naives Regex bis Dateiende).
public enum GetYourGuideInitialState {
    private static let marker = "__INITIAL_STATE__"

    /// Liefert das JSON-Objekt hinter `__INITIAL_STATE__`, oder `nil` wenn nicht gefunden.
    public static func extractJSONObject(fromHTML html: String) -> String? {
        guard let markerRange = html.range(of: marker) else { return nil }
        let afterMarker = html[markerRange.upperBound...]
        guard let openBrace = afterMarker.firstIndex(of: "{") else { return nil }
        guard let closed = scanBalancedObject(in: html, openBrace: openBrace) else { return nil }
        return String(html[openBrace...closed])
    }

    /// Brace-Scan mit String-/Escape-Awareness.
    static func scanBalancedObject(in text: String, openBrace: String.Index) -> String.Index? {
        var depth = 0
        var inString = false
        var isEscaped = false
        var index = openBrace

        while index < text.endIndex {
            let ch = text[index]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if ch == "\\" {
                    isEscaped = true
                } else if ch == "\"" {
                    inString = false
                }
            } else {
                switch ch {
                case "\"":
                    inString = true
                case "{":
                    depth += 1
                case "}":
                    depth -= 1
                    if depth == 0 {
                        return index
                    }
                default:
                    break
                }
            }

            index = text.index(after: index)
        }

        return nil
    }
}
