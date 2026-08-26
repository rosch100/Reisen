import Foundation

/// SSOT: Hub- und UI-URL-Hints für Sync/Session (unabhängig von `webView.url`).
public enum NavigationHintURLs {
    public static func ordered(urlStrings: [String?]) -> [URL] {
        var seen = Set<String>()
        var ordered: [URL] = []

        for urlString in urlStrings {
            guard let urlString, let url = URL(string: urlString) else { continue }
            guard seen.insert(url.absoluteString).inserted else { continue }
            ordered.append(url)
        }
        return ordered
    }

    public static func ordered(localURLString: String?, hubURLString: String?) -> [URL] {
        ordered(urlStrings: [localURLString, hubURLString])
    }

    public static func ordered(hubURLString: String?) -> [URL] {
        ordered(localURLString: nil, hubURLString: hubURLString)
    }
}
