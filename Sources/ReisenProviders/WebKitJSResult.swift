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

    static func int(from result: Any?, key: String) -> Int? {
        if let dict = result as? [String: Any] {
            return intValue(dict[key])
        }
        if let dict = result as? NSDictionary {
            return intValue(dict[key])
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }
}
