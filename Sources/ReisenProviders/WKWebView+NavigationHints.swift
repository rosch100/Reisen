import Foundation
import WebKit

extension WKWebView {
    /// URLs für Session-Kontext: aktuelle Seite, Verlauf, optionale Hub-Hints (unabhängig von der aktuellen URL).
    public func navigationHintURLs(additionalHintURLs: [URL] = []) -> [URL] {
        var seen = Set<String>()
        var ordered: [URL] = []

        func append(_ url: URL?) {
            guard let url else { return }
            let key = url.absoluteString
            guard seen.insert(key).inserted else { return }
            ordered.append(url)
        }

        append(url)
        for item in backForwardList.backList.reversed() {
            append(item.url)
        }
        append(backForwardList.currentItem?.url)
        for item in backForwardList.forwardList {
            append(item.url)
        }
        for url in additionalHintURLs {
            append(url)
        }
        return ordered
    }
}
