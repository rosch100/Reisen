import Foundation
import WebKit
import ReisenDiagnostics

extension WKWebView {
    /// Builds a `URLRequest` using the same session cookies as the embedded browser.
    public func authenticatedRequest(
        url: URL,
        method: String = "GET",
        accept: String = "application/json, text/html, text/plain, */*",
        referer: String? = nil,
        contentType: String? = nil,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async -> URLRequest {
        var request = AuthenticatedURLRequestBuilder.baseRequest(
            url: url,
            method: method,
            accept: accept,
            referer: referer,
            contentType: contentType,
            body: body,
            headers: headers
        )
        let cookies = await allHTTPCookies()
        AuthenticatedURLRequestBuilder.applyCookieHeader(&request, cookies: cookies, url: url)
        return request
    }

    /// Fetches UTF-8 text with session cookies. Throws on non-2xx or empty body.
    public func fetchAuthenticatedText(
        url: URL,
        method: String = "GET",
        accept: String = "application/json, text/html, text/plain, */*",
        referer: String? = nil,
        contentType: String? = nil,
        body: Data? = nil,
        headers: [String: String] = [:],
        timeoutSeconds: TimeInterval = 60
    ) async throws -> String {
        let context = DiagnosticContext.current
        let start = Date()
        if let context {
            await DiagnosticLogger.shared.record(
                AuthenticatedFetchDiagnostics.event(
                    context: context,
                    event: "started",
                    result: .started,
                    url: url
                )
            )
        }

        do {
            var request = await authenticatedRequest(
                url: url,
                method: method,
                accept: accept,
                referer: referer,
                contentType: contentType,
                body: body,
                headers: headers
            )
            request.timeoutInterval = timeoutSeconds
            let (data, response) = try await URLSession.shared.data(for: request)
            let text = try AuthenticatedTextDecode.utf8Text(data: data, response: response)
            if let context {
                await DiagnosticLogger.shared.record(
                    AuthenticatedFetchDiagnostics.event(
                        context: context,
                        event: "completed",
                        result: .succeeded,
                        url: url,
                        durationMilliseconds: elapsedMilliseconds(since: start)
                    )
                )
            }
            return text
        } catch {
            let mapped = AuthenticatedFetchTransport.mapURLSessionError(error)
            if let context {
                let timedOut = (mapped as? AuthenticatedFetchError) == .timedOut
                await DiagnosticLogger.shared.record(
                    AuthenticatedFetchDiagnostics.event(
                        context: context,
                        event: "failed",
                        result: timedOut ? .timedOut : .failed,
                        url: url,
                        durationMilliseconds: elapsedMilliseconds(since: start),
                        reason: timedOut
                            ? "request_timed_out"
                            : DiagnosticRedactor.redact(mapped.localizedDescription),
                        errorType: String(reflecting: type(of: mapped))
                    )
                )
            }
            throw mapped
        }
    }

    /// HTML-Abruf mit Session-Prüfung (HTTP 401/403, Login-Redirect, Login-HTML, optionale Challenge).
    public func fetchAuthenticatedHTML(
        url: URL,
        accept: String = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        referer: String? = nil,
        isLoginHTML: (String) -> Bool,
        isChallengeHTML: ((String) -> Bool)? = nil
    ) async throws -> String {
        let request = await authenticatedRequest(url: url, accept: accept, referer: referer)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return try AuthenticatedHTMLSession.validatedUTF8HTML(
                data: data,
                response: response,
                isLoginHTML: isLoginHTML,
                isChallengeHTML: isChallengeHTML
            )
        } catch {
            throw AuthenticatedFetchTransport.mapURLSessionError(error)
        }
    }

    private func elapsedMilliseconds(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1_000)
    }
}
