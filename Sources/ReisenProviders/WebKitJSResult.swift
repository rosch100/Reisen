import Foundation

/// SSOT: WKWebView `evaluateJavaScript`-Ergebnisse auswerten.
enum WebKitJSResult {
    static func bool(from result: Any?, key: String) -> Bool? {
        if let value = result as? Bool { return value }
        if let dict = result as? [String: Any] {
            return dict[key] as? Bool
        }
        if let dict = result as? NSDictionary {
            return dict[key] as? Bool
        }
        return nil
    }
}
