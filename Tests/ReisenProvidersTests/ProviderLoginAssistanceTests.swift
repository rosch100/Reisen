import Foundation
import Testing
@testable import ReisenProviders

@Test func loginAssistanceSchedulesOncePerURL() {
    var tracker = LoginAssistanceTracker()
    let loginURL = URL(string: "https://kundenbereich.check24.de/login")!
    let nextURL = URL(string: "https://kundenbereich.check24.de/login/step")!

    let firstSchedule = tracker.shouldSchedule(for: loginURL)
    let repeatedSchedule = tracker.shouldSchedule(for: loginURL)
    let nextPageSchedule = tracker.shouldSchedule(for: nextURL)

    #expect(firstSchedule)
    #expect(!repeatedSchedule)
    #expect(nextPageSchedule)

    tracker.reset()
    let rescheduled = tracker.shouldSchedule(for: loginURL)
    #expect(rescheduled)
}

@Test func sameURLReschedulesAfterExhaustResetsTracker() {
    var tracker = LoginAssistanceTracker()
    let loginURL = URL(string: "https://www.traveloka.com/en-en/user/signin")!
    let first = tracker.shouldSchedule(for: loginURL)
    let blocked = tracker.shouldSchedule(for: loginURL)
    #expect(first)
    #expect(!blocked)

    let empty = LoginAutofillResult(anyFieldFilled: false, submitID: nil)
    let step = ProviderLoginAttemptPolicy.nextStep(
        passwordExpected: true,
        result: empty,
        attempt: 3,
        maximumAttempts: 3,
        sawUsernameWithoutPassword: false,
        initialRetryDelays: ProviderLoginAttemptPolicy.defaultRetryDelays
    )
    guard case .exhausted = step else {
        Issue.record("expected exhausted after max attempts, got \(step)")
        return
    }

    // applyCredentials ruft bei Exhaust resetAssistanceScheduling → Tracker.reset()
    tracker.reset()
    let rescheduled = tracker.shouldSchedule(for: loginURL)
    #expect(rescheduled)
}

@Test func emailOnlyStartsPasswordStepWithLongerDelay() {
    let emailOnly = LoginAutofillResult(
        anyFieldFilled: true,
        submitID: "continue",
        userFilled: 1,
        passFilled: 0
    )
    let step = ProviderLoginAttemptPolicy.nextStep(
        passwordExpected: true,
        result: emailOnly,
        attempt: 1,
        maximumAttempts: 3,
        sawUsernameWithoutPassword: false,
        initialRetryDelays: ProviderLoginAttemptPolicy.defaultRetryDelays
    )
    #expect(step == .startPasswordStep(delay: 1.0))
    #expect(
        ProviderLoginAttemptPolicy.passwordStepRetryDelays[0]
            > ProviderLoginAttemptPolicy.defaultRetryDelays[0]
    )
}

@Test func passwordStepRetriesUseLongerDelaysUntilExhaust() {
    let stillEmailOnly = LoginAutofillResult(
        anyFieldFilled: true,
        submitID: nil,
        userFilled: 1,
        passFilled: 0
    )
    let afterFirstPasswordAttempt = ProviderLoginAttemptPolicy.nextStep(
        passwordExpected: true,
        result: stillEmailOnly,
        attempt: 1,
        maximumAttempts: 3,
        sawUsernameWithoutPassword: true,
        initialRetryDelays: ProviderLoginAttemptPolicy.defaultRetryDelays
    )
    #expect(afterFirstPasswordAttempt == .retry(delay: 1.0))

    let afterSecond = ProviderLoginAttemptPolicy.nextStep(
        passwordExpected: true,
        result: stillEmailOnly,
        attempt: 2,
        maximumAttempts: 3,
        sawUsernameWithoutPassword: true,
        initialRetryDelays: ProviderLoginAttemptPolicy.defaultRetryDelays
    )
    #expect(afterSecond == .retry(delay: 2.0))

    let afterThird = ProviderLoginAttemptPolicy.nextStep(
        passwordExpected: true,
        result: stillEmailOnly,
        attempt: 3,
        maximumAttempts: 3,
        sawUsernameWithoutPassword: true,
        initialRetryDelays: ProviderLoginAttemptPolicy.defaultRetryDelays
    )
    guard case .exhausted(let reason) = afterThird else {
        Issue.record("expected exhausted, got \(afterThird)")
        return
    }
    #expect(reason.contains("user_filled=1"))
    #expect(reason.contains("pass_filled=0"))
}

@Test func emptyRetryDelaysExhaustWithoutSilentDefault() {
    let empty = LoginAutofillResult(anyFieldFilled: false, submitID: nil)
    let step = ProviderLoginAttemptPolicy.nextStep(
        passwordExpected: true,
        result: empty,
        attempt: 1,
        maximumAttempts: 3,
        sawUsernameWithoutPassword: false,
        initialRetryDelays: []
    )
    #expect(step == .exhausted(reason: "retry_schedule_missing"))
}
