import Foundation
import Testing
import ReisenDomain
@testable import ReisenProviders

@Test func opodoCancelAssist_shouldRunOnlyOnTripDetails() {
    let detail = URL(
        string: "https://www.opodo.de/travel/secure/?mainProduct=accommodation#tripdetails/;td=TOKEN"
    )!
    let home = URL(string: "https://www.opodo.de/")!
    let other = URL(string: "https://www.example.com/#tripdetails/;td=TOKEN")!
    let lookalike = URL(string: "https://notopodo.de/#tripdetails/;td=TOKEN")!

    #expect(OpodoCancelAssist.isTripDetailsURL(detail))
    #expect(!OpodoCancelAssist.isTripDetailsURL(home))
    #expect(!OpodoCancelAssist.isTripDetailsURL(other))
    #expect(!OpodoCancelAssist.isTripDetailsURL(lookalike))
    #expect(OpodoCancelAssist.isOpodoPortalHost("www.opodo.de"))
    #expect(!OpodoCancelAssist.isOpodoPortalHost("notopodo.de"))
    #expect(OpodoCancelAssist.shouldRun(provider: .opodo, loadedURL: detail))
    #expect(!OpodoCancelAssist.shouldRun(provider: .opodo, loadedURL: home))
    #expect(!OpodoCancelAssist.shouldRun(provider: .billigerMietwagen, loadedURL: detail))
}

@Test func opodoCancelAssistScript_parsesStatusesAndAvoidsFinalConfirm() {
    #expect(OpodoCancelAssistScript.parseStepStatus("already_open") == .alreadyOpen)
    #expect(OpodoCancelAssistScript.parseStepStatus("clicked_entry") == .clickedEntry)
    #expect(OpodoCancelAssistScript.parseStepStatus("entry_missing") == .entryMissing)
    #expect(OpodoCancelAssistScript.parsePollStatus("dialog_open") == .dialogOpen)
    #expect(OpodoCancelAssistScript.parsePollStatus("pending") == .pending)
    #expect(OpodoCancelAssistScript.step.contains("buchung\\s+abbrechen"))
    #expect(OpodoCancelAssistScript.step.contains("diese\\s+buchung\\s+stornieren"))
    #expect(OpodoCancelAssistScript.step.contains("continue"))
    #expect(
        OpodoCancelAssistScript.step.contains(
            PortalCancelCompletionDetector.opodoAlreadyCancelledPattern
        )
    )
    #expect(
        OpodoCancelAssistScript.poll.contains(
            PortalCancelCompletionDetector.opodoAlreadyCancelledPattern
        )
    )
    #expect(OpodoCancelAssistScript.step.contains(OpodoCancelAssist.portalHost))
}
