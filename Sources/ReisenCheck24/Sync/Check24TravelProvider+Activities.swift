import Foundation
import WebKit
import ReisenProviders

extension Check24TravelProvider {
    func fetchActivitiesJSON(using webView: WKWebView) async throws -> String {
        guard let url = URL(string: "https://kundenbereich.check24.de/kb/api/activities") else {
            throw Check24ProviderError.activitiesFetchFailed("ungültige Activities-URL")
        }

        var lastDetail = "unbekannt"
        for attempt in 1...3 {
            do {
                let text = try await webView.fetchAuthenticatedText(url: url)
                guard text.contains("\"activities\"") else {
                    let preview = String(text.prefix(120)).replacingOccurrences(of: "\n", with: " ")
                    throw Check24ProviderError.activitiesFetchFailed(
                        "Antwort enthält keine activities: \(preview)"
                    )
                }
                try persistActivitiesJSONSnapshot(text)
                return text
            } catch let error as AuthenticatedFetchError where AuthenticatedSessionGuard.isUnauthorized(error) {
                throw Check24ProviderError.sessionNotEstablished
            } catch let error as Check24ProviderError {
                lastDetail = error.localizedDescription
                if attempt < 3 {
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 400_000_000)
                    continue
                }
                throw error
            } catch {
                lastDetail = error.localizedDescription
                if attempt < 3 {
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 400_000_000)
                    continue
                }
            }
        }
        throw Check24ProviderError.activitiesFetchFailed(lastDetail)
    }

    func fetchActivitiesHTML(using webView: WKWebView) async throws -> String {
        do {
            return try await webView.fetchAuthenticatedHTML(
                url: Check24TravelProvider.activitiesPageURL,
                referer: Check24TravelProvider.activitiesPageURL.absoluteString,
                isLoginHTML: { AuthPageHTMLHeuristic.check24LooksLikeLoginHTML($0) }
            )
        } catch AuthenticatedSessionError.notEstablished {
            throw Check24ProviderError.sessionNotEstablished
        }
    }

    func persistActivitiesJSONSnapshot(_ json: String) throws {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw Check24ProviderError.snapshotFailed
        }
        let base = appSupport.appendingPathComponent("Reisen", isDirectory: true)
        let snapshots = base.appendingPathComponent("snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)
        let fileName = "activities-\(ISO8601DateFormatter().string(from: Date())).json"
        let url = snapshots.appendingPathComponent(fileName)
        guard let data = json.data(using: .utf8) else {
            throw Check24ProviderError.snapshotFailed
        }
        try data.write(to: url, options: [.atomic])
    }
}
