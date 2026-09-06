import Foundation
import Testing
import ReisenDiagnostics
import ReisenDomain
import ReisenProviders

@MainActor
struct NavigationSettleLoopDiagnosticsTests {
    @Test("NavigationSettleLoop: kein poll/settle_check-Flood bei Dauer-isLoading")
    func settleLoop_doesNotEmitTickPollOrSettleCheck() async throws {
        let url = URL(string: "https://hotel.check24.de/kundenbereich/buchung/abc")!
        let webView = FakeNavigationWebView(url: url, isLoading: true)
        let context = DiagnosticContext(
            runID: UUID(),
            providerID: .check24,
            operation: "provider_sync"
        )

        nonisolated(unsafe) var recorded: [String] = []
        DiagnosticLogger.notePublicEvent = { event in
            guard event.context.runID == context.runID else { return }
            recorded.append(event.event)
        }
        defer { DiagnosticLogger.notePublicEvent = nil }

        try await NavigationSettleLoop.wait(
            webView: webView,
            targetHost: "hotel.check24.de",
            targetPath: "/kundenbereich/buchung/abc",
            deadline: Date().addingTimeInterval(5),
            timeoutURL: url,
            diagnosticContext: context
        )
        await DiagnosticLogger.shared.flush()

        #expect(!recorded.contains("poll"))
        #expect(!recorded.contains("settle_check"))
    }
}
