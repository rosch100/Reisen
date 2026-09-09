import Testing

import ReisenDomain
import ReisenSharedUI

@Test func providerSetupSelection_emptyBecomesAll() {
    let all: [ProviderID] = [.check24, .opodo]
    let result = ProviderSetupSelection.toggleAll(current: [], allIDs: all)
    #expect(result == Set(all))
}

@Test func providerSetupSelection_partialBecomesAll() {
    let all: [ProviderID] = [.check24, .opodo, .booking]
    let result = ProviderSetupSelection.toggleAll(current: [.opodo], allIDs: all)
    #expect(result == Set(all))
}

@Test func providerSetupSelection_allBecomesEmpty() {
    let all: [ProviderID] = [.check24, .opodo]
    let result = ProviderSetupSelection.toggleAll(current: Set(all), allIDs: all)
    #expect(result.isEmpty)
}

@Test func providerSetupSelection_emptyAllIDsStaysEmpty() {
    let result = ProviderSetupSelection.toggleAll(current: [.check24], allIDs: [])
    #expect(result.isEmpty)
}

@Test func providerSetupSelection_areAllSelected_requiresNonEmptyCompleteSet() {
    let all: [ProviderID] = [.check24, .opodo]
    #expect(!ProviderSetupSelection.areAllSelected(current: [], allIDs: all))
    #expect(!ProviderSetupSelection.areAllSelected(current: [.check24], allIDs: all))
    #expect(ProviderSetupSelection.areAllSelected(current: Set(all), allIDs: all))
    #expect(!ProviderSetupSelection.areAllSelected(current: [.check24], allIDs: []))
}
