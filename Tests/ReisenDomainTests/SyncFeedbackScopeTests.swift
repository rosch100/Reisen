import Testing
import ReisenDomain

@Test func syncFeedbackScope_hidesBookingErrorUnderCheck24Selection() {
    #expect(
        !SyncFeedbackScope.belongsToSelectedProvider(
            selected: .check24,
            isSyncing: false,
            syncingProviderID: nil,
            messageProviderID: .booking
        )
    )
}

@Test func syncFeedbackScope_showsCheck24ErrorWhenSelected() {
    #expect(
        SyncFeedbackScope.belongsToSelectedProvider(
            selected: .check24,
            isSyncing: false,
            syncingProviderID: nil,
            messageProviderID: .check24
        )
    )
}

@Test func syncFeedbackScope_syncAllAggregateIsNotProviderScoped() {
    #expect(
        !SyncFeedbackScope.belongsToSelectedProvider(
            selected: .check24,
            isSyncing: false,
            syncingProviderID: nil,
            messageProviderID: nil
        )
    )
    #expect(SyncFeedbackScope.showsUnscopedAggregateBanner(messageProviderID: nil))
    #expect(!SyncFeedbackScope.showsUnscopedAggregateBanner(messageProviderID: .booking))
}

@Test func syncFeedbackScope_duringSyncShowsOnlyActiveProvider() {
    #expect(
        SyncFeedbackScope.belongsToSelectedProvider(
            selected: .check24,
            isSyncing: true,
            syncingProviderID: .check24,
            messageProviderID: .booking
        )
    )
    #expect(
        !SyncFeedbackScope.belongsToSelectedProvider(
            selected: .check24,
            isSyncing: true,
            syncingProviderID: .booking,
            messageProviderID: .booking
        )
    )
}
