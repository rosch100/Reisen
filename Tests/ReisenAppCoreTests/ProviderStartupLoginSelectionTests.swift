import Testing
import ReisenDomain
import ReisenAppCore

/// Regression: Startup-Bootstrap darf keinen Index in die live Enabled-Liste re-indexieren
/// (Crash Array._checkSubscript in ProviderSyncContainer.swift nach await Probe).
@Test func providerStartupLoginSelection_returnsFirstNeedingByStableID() {
    let snapshot: [ProviderID] = [.check24, .booking, .airbnb]
    let ready: Set<ProviderID> = [.check24]

    let first = ProviderStartupLoginSelection.firstNeedingLogin(
        providersInOrder: snapshot,
        isSessionReady: { ready.contains($0) }
    )

    #expect(first == .booking)
}

@Test func providerStartupLoginSelection_nilWhenAllReady() {
    let snapshot: [ProviderID] = [.booking, .airbnb]
    let first = ProviderStartupLoginSelection.firstNeedingLogin(
        providersInOrder: snapshot,
        isSessionReady: { _ in true }
    )
    #expect(first == nil)
}

@Test func providerStartupLoginSelection_remainingUsesSnapshotOrderNotLiveIndex() {
    let snapshot: [ProviderID] = [.check24, .booking, .airbnb, .opodo]
    // Live-Liste schrumpft (Prefs/Toggle während await) — Index 1 wäre OOB auf leerer Liste.
    let stillEnabled: Set<ProviderID> = [.airbnb, .opodo]

    let remaining = ProviderStartupLoginSelection.remainingToProbe(
        providersInOrder: snapshot,
        after: .booking,
        stillEnabled: stillEnabled
    )

    #expect(remaining == [.airbnb, .opodo])
}

@Test func providerStartupLoginSelection_remainingSkipsSelectedEvenIfStillEnabled() {
    let snapshot: [ProviderID] = [.booking, .airbnb]
    let remaining = ProviderStartupLoginSelection.remainingToProbe(
        providersInOrder: snapshot,
        after: .booking,
        stillEnabled: [.booking, .airbnb]
    )
    #expect(remaining == [.airbnb])
}

@Test func providerStartupLoginSelection_emptySnapshotYieldsNilWithoutTrap() {
    let first = ProviderStartupLoginSelection.firstNeedingLogin(
        providersInOrder: [],
        isSessionReady: { _ in false }
    )
    #expect(first == nil)
}

/// Regression: Advance darf nicht auf deaktiviertes Airbnb springen, wenn Check24 schon ready ist.
@Test func providerStartupLoginSelection_nextAfterComplete_skipsDisabledProviders() {
    let queue: [ProviderID] = [.check24, .airbnb, .opodo]
    let stillEnabled: Set<ProviderID> = [.check24, .opodo]

    let next = ProviderStartupLoginSelection.nextAfterCompleting(
        completed: .check24,
        in: queue,
        stillEnabled: stillEnabled
    )

    #expect(next == .opodo)
}

@Test func providerStartupLoginSelection_nextAfterComplete_nilWhenOnlyDisabledRemain() {
    let queue: [ProviderID] = [.check24, .airbnb]
    let stillEnabled: Set<ProviderID> = [.check24]

    let next = ProviderStartupLoginSelection.nextAfterCompleting(
        completed: .check24,
        in: queue,
        stillEnabled: stillEnabled
    )

    #expect(next == nil)
}

@Test func providerStartupLoginSelection_prunedQueue_dropsDisabledKeepingOrder() {
    let pruned = ProviderStartupLoginSelection.prunedQueue(
        [.check24, .airbnb, .booking, .opodo],
        stillEnabled: [.check24, .opodo]
    )
    #expect(pruned == [ProviderID.check24, ProviderID.opodo])
}
