import Foundation
import WebKit
import ReisenDiagnostics
import ReisenProviders

extension Check24TravelProvider {
    func fetchActivitiesJSON(using webView: WKWebView) async throws -> String {
        let url = Check24SessionProbe.activitiesAPIURL
        await recordDiagnosticPhase(
            "activity",
            event: "started",
            result: .started,
            url: url
        )

        var lastDetail = "unbekannt"
        for attempt in 1...3 {
            do {
                await recordDiagnosticPhase(
                    "activity",
                    event: "attempt",
                    result: .started,
                    url: url,
                    reason: "attempt=\(attempt)"
                )
                let text = try await webView.fetchAuthenticatedText(url: url)
                guard text.contains("\"activities\"") else {
                    let preview = String(text.prefix(120)).replacingOccurrences(of: "\n", with: " ")
                    throw Check24ProviderError.activitiesFetchFailed(
                        "Antwort enthält keine activities: \(preview)"
                    )
                }
                try persistActivitiesJSONSnapshot(text)
                await recordDiagnosticPhase(
                    "activity",
                    event: "completed",
                    result: .succeeded,
                    url: url,
                    reason: "attempt=\(attempt)"
                )
                return text
            } catch let error as AuthenticatedFetchError where AuthenticatedSessionGuard.isUnauthorized(error) {
                await recordDiagnosticPhase(
                    "activity",
                    event: "failed",
                    result: .failed,
                    url: url,
                    reason: "session_not_established"
                )
                throw Check24ProviderError.sessionNotEstablished
            } catch let error as Check24ProviderError {
                lastDetail = error.localizedDescription
                await recordDiagnosticPhase(
                    "activity",
                    event: "attempt_failed",
                    result: .failed,
                    url: url,
                    reason: error.localizedDescription
                )
                if attempt < 3 {
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 400_000_000)
                    continue
                }
                throw error
            } catch {
                lastDetail = error.localizedDescription
                await recordDiagnosticPhase(
                    "activity",
                    event: "attempt_failed",
                    result: .failed,
                    url: url,
                    reason: error.localizedDescription
                )
                if attempt < 3 {
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 400_000_000)
                    continue
                }
            }
        }
        await recordDiagnosticPhase(
            "activity",
            event: "failed",
            result: .failed,
            url: url,
            reason: lastDetail
        )
        throw Check24ProviderError.activitiesFetchFailed(lastDetail)
    }

    func fetchActivitiesHTML(using webView: WKWebView) async throws -> String {
        do {
            return try await webView.fetchAuthenticatedHTML(
                url: Check24TravelProvider.activitiesPageURL,
                referer: Check24TravelProvider.activitiesPageURL.absoluteString,
                isLoginHTML: AuthPageHTMLHeuristic.check24LooksLikeLoginHTML
            )
        } catch AuthenticatedSessionError.notEstablished {
            throw Check24ProviderError.sessionNotEstablished
        }
    }

    func persistActivitiesJSONSnapshot(_ json: String) throws {
        guard let base = ReisenApplicationSupport.directoryURL() else {
            throw Check24ProviderError.snapshotFailed
        }
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
