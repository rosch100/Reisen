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
