import Foundation
import Testing
import ReisenDiagnostics
@testable import ReisenAppCore

@Suite
struct ProviderFirstLaunchSetupDiagnosticsTests {
    @Test func makeEvent_fields() {
        let event = ProviderFirstLaunchSetupDiagnostics.makeEvent(
            event: ProviderFirstLaunchSetupDiagnostics.presentedEvent,
            result: .started,
            reason: "fresh_launch"
        )
        #expect(event.component == "ProviderFirstLaunchSetup")
        #expect(event.phase == "setup")
        #expect(event.event == "provider_setup_presented")
        #expect(event.result == .started)
        #expect(event.reason == "fresh_launch")
        #expect(event.context.operation == "provider_first_launch_setup")
        #expect(event.context.providerID == .manual)
    }

    @Test func recordCompleted_reasonIncludesCount() {
        let event = ProviderFirstLaunchSetupDiagnostics.makeEvent(
            event: ProviderFirstLaunchSetupDiagnostics.completedEvent,
            result: .succeeded,
            reason: "continue_count_2"
        )
        #expect(event.event == "provider_setup_completed")
        #expect(event.result == .succeeded)
        #expect(event.reason == "continue_count_2")
    }

    @Test func recordDeferred_fields() {
        let event = ProviderFirstLaunchSetupDiagnostics.makeEvent(
            event: ProviderFirstLaunchSetupDiagnostics.deferredEvent,
            result: .cancelled,
            reason: "later"
        )
        #expect(event.event == "provider_setup_deferred")
        #expect(event.result == .cancelled)
        #expect(event.reason == "later")
    }
}
