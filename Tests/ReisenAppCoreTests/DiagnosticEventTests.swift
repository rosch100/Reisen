import Foundation
import Testing
import ReisenDomain
@testable import ReisenAppCore

@Test func diagnosticEvent_roundTripsAsCodableJSON() throws {
    let context = DiagnosticContext(
        runID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
        providerID: .check24,
        operation: "startup_probe"
    )
    let event = DiagnosticEvent(
        context: context,
        component: "ProviderSessionView",
        phase: "navigation",
        event: "did_finish",
        result: .succeeded,
        attempt: 1,
        durationMilliseconds: 420,
        url: "kundenbereich.check24.de/user/account/activities.html",
        errorType: nil,
        reason: nil,
        visibility: .publicDiagnostic
    )

    let data = try JSONEncoder().encode(event)
    let decoded = try JSONDecoder().decode(DiagnosticEvent.self, from: data)

    #expect(decoded == event)
}

@Test func diagnosticEvent_preservesExplicitResultAndVisibility() {
    let context = DiagnosticContext(
        runID: UUID(),
        providerID: .check24,
        operation: "auto_login"
    )
    let event = DiagnosticEvent(
        context: context,
        component: "ProviderLoginAssistance",
        phase: "submit",
        event: "credentials_filled",
        result: .succeeded,
        attempt: 2,
        durationMilliseconds: nil,
        url: nil,
        errorType: nil,
        reason: nil,
        visibility: .localDebugOnly
    )

    #expect(event.result == .succeeded)
    #expect(event.visibility == .localDebugOnly)
}

@Test func diagnosticContextTaskLocalPreservesCorrelationID() {
    let context = DiagnosticContext(
        runID: UUID(),
        providerID: .check24,
        operation: "correlation"
    )

    let current = DiagnosticContext.$current.withValue(context) {
        DiagnosticContext.current
    }

    #expect(current == context)
}

@Test func diagnosticEventPreservesProbeMetadata() {
    let event = DiagnosticEvent(
        context: DiagnosticContext(
            runID: UUID(),
            providerID: .check24,
            operation: "startup_probe"
        ),
        component: "ProviderSessionProbeHost",
        phase: "session_probe",
        event: "completed",
        result: .succeeded,
        durationMilliseconds: 1250,
        url: "kundenbereich.check24.de/account",
        reason: "source=provider_login_url",
        statusBefore: "needsLogin",
        statusAfter: "sessionReady"
    )

    #expect(event.durationMilliseconds == 1250)
    #expect(event.url == "kundenbereich.check24.de/account")
    #expect(event.statusBefore == "needsLogin")
    #expect(event.statusAfter == "sessionReady")
}
