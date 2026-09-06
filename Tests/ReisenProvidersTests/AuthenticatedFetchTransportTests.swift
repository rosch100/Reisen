import Testing
import Foundation
import ReisenProviders
import ReisenDiagnostics
import ReisenDomain

@Test func authenticatedFetchError_timedOutHasTypedDescription() {
    let error = AuthenticatedFetchError.timedOut
    #expect(error.errorDescription == "Authentifizierter Abruf: Zeitüberschreitung.")
}

@Test func authenticatedFetchTransport_mapsURLErrorTimedOut() {
    let mapped = AuthenticatedFetchTransport.mapURLSessionError(
        URLError(.timedOut)
    )
    #expect(mapped is AuthenticatedFetchError)
    guard let fetchError = mapped as? AuthenticatedFetchError else { return }
    #expect(fetchError == .timedOut)
}

@Test func authenticatedFetchTransport_passesThroughOtherErrors() {
    let original = URLError(.notConnectedToInternet)
    let mapped = AuthenticatedFetchTransport.mapURLSessionError(original)
    #expect((mapped as? URLError)?.code == .notConnectedToInternet)
}

@Test func authenticatedFetchDiagnostics_startedEvent() {
    let context = DiagnosticContext(runID: UUID(), providerID: .opodo, operation: "provider_sync")
    let url = URL(string: "https://www.opodo.de/graphql")!
    let event = AuthenticatedFetchDiagnostics.event(
        context: context,
        event: "started",
        result: .started,
        url: url
    )
    #expect(event.component == "AuthenticatedFetch")
    #expect(event.phase == "authenticated_fetch")
    #expect(event.event == "started")
    #expect(event.result == .started)
    #expect(event.url == url.absoluteString)
}

@Test func authenticatedFetchDiagnostics_timedOutEvent() {
    let context = DiagnosticContext(runID: UUID(), providerID: .opodo, operation: "provider_sync")
    let url = URL(string: "https://www.opodo.de/graphql")!
    let event = AuthenticatedFetchDiagnostics.event(
        context: context,
        event: "failed",
        result: .timedOut,
        url: url,
        durationMilliseconds: 60_110,
        reason: "request_timed_out"
    )
    #expect(event.result == .timedOut)
    #expect(event.reason == "request_timed_out")
    #expect(event.durationMilliseconds == 60_110)
}
