import Foundation

enum ExpediaJSON {
    static func string(_ any: Any?) -> String? {
        if let s = any as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        return nil
    }

    static func dict(_ any: Any?) -> [String: Any]? {
        any as? [String: Any]
    }

    static func array(_ any: Any?) -> [Any]? {
        any as? [Any]
    }

    /// Depth-first walk; dictionary keys in sorted order for deterministic extraction.
    static func walkDepthFirst(_ root: Any, visit: (Any) -> Void) {
        func walk(_ node: Any) {
            visit(node)
            if let d = node as? [String: Any] {
                for k in d.keys.sorted() {
                    if let v = d[k] { walk(v) }
                }
            } else if let a = node as? [Any] {
                for v in a { walk(v) }
            }
        }
        walk(root)
    }

    /// First dictionary matching `predicate`, depth-first with sorted keys.
    static func firstDictionary(
        in root: Any,
        where predicate: ([String: Any]) -> Bool
    ) -> [String: Any]? {
        var found: [String: Any]?
        walkDepthFirst(root) { node in
            guard found == nil, let d = node as? [String: Any], predicate(d) else { return }
            found = d
        }
        return found
    }

    /// Walks nested dictionaries/arrays and collects values for `key`.
    static func collectStrings(key: String, in root: Any, limit: Int = 64) -> [String] {
        var out: [String] = []
        walkDepthFirst(root) { node in
            guard out.count < limit, let d = node as? [String: Any], let s = string(d[key]) else {
                return
            }
            out.append(s)
        }
        return out
    }

    static func firstString(keys: [String], in root: Any) -> String? {
        for key in keys {
            if let s = collectStrings(key: key, in: root, limit: 1).first {
                return s
            }
        }
        return nil
    }

    static func parseEuroAmount(_ text: String) -> (Decimal, String)? {
        let normalized = text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.contains("€") || normalized.lowercased().contains("eur") else {
            return nil
        }
        // Amount token immediately before €/EUR (optional spaces): `Gesamtpreis: 1.234,56 €`.
        let pattern = #"(\d{1,3}(?:\.\d{3})*(?:,\d{1,2})?|\d+(?:,\d{1,2})?)\s*(?:€|EUR)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        guard let match = regex.firstMatch(in: normalized, options: [], range: range),
              let amountRange = Range(match.range(at: 1), in: normalized)
        else {
            return nil
        }
        var digits = String(normalized[amountRange])
        // de: 1.234,56 → 1234.56 ; 1.234 without decimals stays 1234
        if digits.contains(",") {
            digits = digits.replacingOccurrences(of: ".", with: "")
            digits = digits.replacingOccurrences(of: ",", with: ".")
        } else if digits.contains(".") {
            let parts = digits.split(separator: ".", omittingEmptySubsequences: false)
            if parts.count == 2, parts[1].count == 3, parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) {
                digits = digits.replacingOccurrences(of: ".", with: "")
            }
        }
        guard let amount = Decimal(string: digits) else { return nil }
        return (amount, "EUR")
    }
}
