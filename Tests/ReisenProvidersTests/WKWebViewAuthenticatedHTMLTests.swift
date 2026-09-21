import Foundation
import Testing
import WebKit
import ReisenDiagnostics
import ReisenDomain
import ReisenProviders

@Suite(.serialized)
@MainActor
struct WKWebViewAuthenticatedHTMLTests {
    private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
        nonisolated(unsafe) static var lastRequest: URLRequest?
        nonisolated(unsafe) static var responseHTML = "<html><body>trips</body></html>"
        nonisolated(unsafe) static var failWithTimedOut = false

        override class func canInit(with request: URLRequest) -> Bool {
            request.url?.host == "authenticated-html-test.local"
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            Self.lastRequest = request
            if Self.failWithTimedOut {
                client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
                return
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html; charset=utf-8"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(Self.responseHTML.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    private func withStubProtocol(_ operation: () async throws -> Void) async rethrows {
        URLProtocol.registerClass(StubURLProtocol.self)
        defer { URLProtocol.unregisterClass(StubURLProtocol.self) }
        StubURLProtocol.lastRequest = nil
        StubURLProtocol.failWithTimedOut = false
        try await operation()
    }

    @Test("fetchAuthenticatedHTML setzt request.timeoutInterval wie fetchAuthenticatedText")
    func setsRequestTimeoutFromParameter() async throws {
        try await withStubProtocol {
            let url = URL(string: "https://authenticated-html-test.local/trips")!
            let webView = WKWebView()
            _ = try await webView.fetchAuthenticatedHTML(
                url: url,
                timeoutSeconds: 42,
                isLoginHTML: { _ in false }
            )
            #expect(StubURLProtocol.lastRequest?.timeoutInterval == 42)
        }
    }

    @Test("fetchAuthenticatedHTML emittiert AuthenticatedFetch started/completed")
    func emitsAuthenticatedFetchDiagnosticsOnSuccess() async throws {
        try await withStubProtocol {
            let context = DiagnosticContext(
                runID: UUID(),
                providerID: .expedia,
                operation: "provider_sync"
            )
            nonisolated(unsafe) var recorded: [(String, DiagnosticResult)] = []
            DiagnosticLogger.notePublicEvent = { event in
                guard event.context.runID == context.runID else { return }
                recorded.append((event.event, event.result))
            }
            defer { DiagnosticLogger.notePublicEvent = nil }

            let url = URL(string: "https://authenticated-html-test.local/trips")!
            let webView = WKWebView()
            try await DiagnosticContext.$current.withValue(context) {
                _ = try await webView.fetchAuthenticatedHTML(
                    url: url,
                    isLoginHTML: { _ in false }
                )
            }
            await DiagnosticLogger.shared.flush()

            #expect(recorded.contains { $0.0 == "started" && $0.1 == .started })
            #expect(recorded.contains { $0.0 == "completed" && $0.1 == .succeeded })
        }
    }

    @Test("fetchAuthenticatedHTML emittiert AuthenticatedFetch failed bei Timeout")
    func emitsAuthenticatedFetchDiagnosticsOnTimeout() async throws {
        try await withStubProtocol {
            StubURLProtocol.failWithTimedOut = true
            let context = DiagnosticContext(
                runID: UUID(),
                providerID: .expedia,
                operation: "provider_sync"
            )
            nonisolated(unsafe) var recorded: [(String, DiagnosticResult, String?)] = []
            DiagnosticLogger.notePublicEvent = { event in
                guard event.context.runID == context.runID else { return }
                recorded.append((event.event, event.result, event.reason))
            }
            defer { DiagnosticLogger.notePublicEvent = nil }

            let url = URL(string: "https://authenticated-html-test.local/trips")!
            let webView = WKWebView()
            do {
                try await DiagnosticContext.$current.withValue(context) {
                    _ = try await webView.fetchAuthenticatedHTML(
                        url: url,
                        isLoginHTML: { _ in false }
                    )
                }
                Issue.record("expected timeout")
            } catch let error as AuthenticatedFetchError {
                #expect(error == .timedOut)
            }
            await DiagnosticLogger.shared.flush()

            #expect(recorded.contains { $0.0 == "started" && $0.1 == .started })
            #expect(recorded.contains {
                $0.0 == "failed" && $0.1 == .timedOut && $0.2 == "request_timed_out"
            })
        }
    }
}
