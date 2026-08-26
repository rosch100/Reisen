import Testing
import ReisenDomain

@Test func enabledProviderSelection_keepsSelectedWhenStillEnabled() {
    let enabled: [ProviderID] = [.check24, .opodo, .booking]
    #expect(
        EnabledProviderSelection.resolved(selected: .opodo, enabled: enabled) == .opodo
    )
}

@Test func enabledProviderSelection_fallsBackToFirstWhenSelectedDisabled() {
    let enabled: [ProviderID] = [.opodo, .booking]
    #expect(
        EnabledProviderSelection.resolved(selected: .check24, enabled: enabled) == .opodo
    )
}

@Test func enabledProviderSelection_returnsNilWhenNoneEnabled() {
    #expect(
        EnabledProviderSelection.resolved(selected: .check24, enabled: []) == nil
    )
}
