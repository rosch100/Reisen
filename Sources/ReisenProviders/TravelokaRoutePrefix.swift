import Foundation

/// SSOT: Traveloka-Locale-Pfad (`en-en`, `id-id`, …) aus URLs und API-Sprachcodes.
public enum TravelokaRoutePrefix {
    public static func isValid(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: true)
        guard parts.count == 2 else { return false }
        return parts[0].count == 2 && parts[1].count == 2
            && parts.allSatisfy { $0.allSatisfy(\.isLetter) }
    }

    public static func extract(from url: URL?) -> String? {
        guard let url else { return nil }
        return extract(fromAbsoluteString: url.absoluteString)
    }

    public static func extract(fromAbsoluteString absoluteString: String) -> String? {
        guard let url = URL(string: absoluteString),
              let host = url.host?.lowercased(),
              host == "traveloka.com" || host.hasSuffix(".traveloka.com")
        else {
            return nil
        }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let first = parts.first, isValid(first) else { return nil }
        return first.lowercased()
    }

    /// `en_EN` → `en-en`, `id_ID` → `id-id`.
    public static func fromAPILanguage(_ language: String) -> String? {
        let trimmed = language.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: "-", with: "_")
        let parts = normalized.split(separator: "_", omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        let candidate = "\(parts[0].lowercased())-\(parts[1].lowercased())"
        return isValid(candidate) ? candidate : nil
    }
}
