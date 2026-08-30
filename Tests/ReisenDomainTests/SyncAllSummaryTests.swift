import Testing
import Foundation
import ReisenDomain

private func withGermanL10n(_ body: () throws -> Void) rethrows {
    try L10n.withLocale(Locale(identifier: "de"), body)
}

@Test func syncAllSummary_statusLine_countsSuccessAndFailure() throws {
    try withGermanL10n {
        let expected = L10n.format(
            .syncAllFinishedWithParts,
            [L10n.format(.syncAllPartOk, 1), L10n.format(.syncAllPartFailed, 3)].joined(separator: ", ")
        )
        #expect(SyncAllSummary.statusLine(successCount: 1, failureCount: 3) == expected)
    }
}

@Test func syncAllSummary_completionLine_distinguishesRestrictedAndFailures() throws {
    try withGermanL10n {
        let expected = L10n.format(
            .syncAllFinishedWithParts,
            [
                L10n.format(.syncAllPartOk, 2),
                L10n.format(.syncAllPartRestricted, 1),
                L10n.format(.syncAllPartFailed, 1),
            ].joined(separator: ", ")
        )
        #expect(
            SyncAllSummary.completionLine(
                fullSuccessCount: 2,
                privacyRestrictedCount: 1,
                failureCount: 1
            ) == expected
        )
    }
}

@Test func syncAllSummary_allProvidersSyncedLine_mentionsRestrictedProviders() throws {
    try withGermanL10n {
        let expected = L10n.format(
            .syncAllFinishedWithParts,
            [L10n.format(.syncAllPartOk, 1), L10n.format(.syncAllPartRestricted, 2)].joined(separator: ", ")
        )
        #expect(
            SyncAllSummary.allProvidersSyncedLine(fullSuccessCount: 1, privacyRestrictedCount: 2)
            == expected
        )
    }
}

@Test func syncAllSummary_providerFailureMessage_usesLocalizedFallback() throws {
    try withGermanL10n {
        #expect(SyncAllSummary.providerFailureMessage(errorMessage: "Timeout") == "Timeout")
        #expect(
            SyncAllSummary.providerFailureMessage(errorMessage: nil)
                == L10n.string(.syncUnknownError)
        )
    }
}

@Test func syncAllSummary_aggregateMixedProviderRuns_matchesSyncAllLoop() throws {
    try withGermanL10n {
        let runs: [(errorMessage: String?, finishOutcome: ProviderSyncFinishOutcome?)] = [
            (nil, .fullSuccess),
            (nil, .privacyRestricted),
            ("Timeout", nil),
            (nil, .sideEffectFailure),
        ]

        var aggregation = SyncAllAggregation()
        for (index, run) in runs.enumerated() {
            aggregation.recordProviderRun(
                ProviderSyncRunOutcome(
                    providerName: "Provider \(index)",
                    errorMessage: run.errorMessage,
                    finishOutcome: run.finishOutcome
                )
            )
        }

        #expect(aggregation.fullSuccessCount == 1)
        #expect(aggregation.privacyRestrictedCount == 1)
        #expect(aggregation.failures.count == 2)
        #expect(aggregation.hasFailures)

        let expected = L10n.format(
            .syncAllFinishedWithParts,
            [
                L10n.format(.syncAllPartOk, 1),
                L10n.format(.syncAllPartRestricted, 1),
                L10n.format(.syncAllPartFailed, 2),
            ].joined(separator: ", ")
        )
        #expect(aggregation.completionLine == expected)
    }
}

@Test func syncAllAggregation_finishPresentation_splitsSuccessAndFailure() throws {
    try withGermanL10n {
        var failed = SyncAllAggregation()
        failed.recordProviderRun(
            ProviderSyncRunOutcome(
                providerName: "Opodo",
                errorMessage: "Timeout",
                finishOutcome: nil
            )
        )

        guard case .hasFailures(let errorDetails, _, let completionLine) = failed.finishPresentation else {
            Issue.record("Erwartet hasFailures")
            return
        }
        #expect(errorDetails == "Opodo: Timeout")
        #expect(completionLine == L10n.format(.syncAllFinishedWithParts, L10n.format(.syncAllPartFailed, 1)))

        var succeeded = SyncAllAggregation()
        succeeded.recordProviderRun(
            ProviderSyncRunOutcome(providerName: "Check24", finishOutcome: .fullSuccess)
        )

        guard case .allSucceeded(let baseLine, let skippedPrivacy) = succeeded.finishPresentation else {
            Issue.record("Erwartet allSucceeded")
            return
        }
        #expect(baseLine == L10n.format(.syncAllAllProvidersSynced, 1))
        #expect(skippedPrivacy.isEmpty)
    }
}

@Test func syncAllSummary_bucketProviderRun_classifiesMixedOutcomes() {
    #expect(
        SyncAllSummary.bucketProviderRun(errorMessage: "Timeout", finishOutcome: nil)
            == .failure
    )
    #expect(
        SyncAllSummary.bucketProviderRun(errorMessage: nil, finishOutcome: .fullSuccess)
            == .fullSuccess
    )
    #expect(
        SyncAllSummary.bucketProviderRun(errorMessage: nil, finishOutcome: .privacyRestricted)
            == .privacyRestricted
    )
    #expect(
        SyncAllSummary.bucketProviderRun(
            errorMessage: "Kalenderzugriff verweigert",
            finishOutcome: .sideEffectFailure
        ) == .failure
    )
    #expect(
        SyncAllSummary.bucketProviderRun(errorMessage: nil, finishOutcome: .sideEffectFailure)
            == .failure
    )
}

@Test func syncAllSummary_sideEffectFailureMessages_setsErrorAndStatus() throws {
    try withGermanL10n {
        let base = L10n.format(.syncResultCompleted, 3, 2)
        let messages = SyncAllSummary.sideEffectFailureMessages(
            base: base,
            detail: "Kalenderzugriff verweigert"
        )
        let expectedError = L10n.format(.syncSideEffectsError, "Kalenderzugriff verweigert")

        #expect(messages.errorMessage == expectedError)
        #expect(messages.statusMessage == "\(base) \(expectedError)")
    }
}

@Test func draftEnrichmentNeeds_requiresPaidDeadlineWhenRequested() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let completeHotel = ProviderBookingDraft(
        provider: .booking,
        bookingType: .hotel,
        title: "Hotel",
        startAt: now,
        endAt: now.addingTimeInterval(86_400),
        locationToAddress: "Street 1",
        status: .confirmed,
        deadlines: [
            CancellationDeadline(deadlineAt: now, policyText: "Free", isFreeCancellation: true),
        ],
        rateDetails: BookingRateDetails(roomCategory: "Double"),
        hotelCheckInMinutes: 15 * 60,
        hotelCheckOutMinutes: 11 * 60
    )

    #expect(DraftEnrichmentNeeds.shouldEnrich(completeHotel, requiresDeadlines: true))
    #expect(!DraftEnrichmentNeeds.shouldEnrich(completeHotel, requiresDeadlines: false))
}

@Test func syncAllSummary_errorDetails_listsEveryProviderReason() {
    let details = SyncAllSummary.errorDetails(failures: [
        (providerName: "Check24", message: "Keine Buchungsdaten (Start/Ende) konnten im Snapshot gefunden werden."),
        (providerName: "Opodo", message: "Keine Opodo-Buchungen im HTML gefunden."),
        (providerName: "Booking.com", message: "Navigation-Timeout für https://secure.booking.com/mytrips.de.html"),
    ])

    #expect(details == """
        Check24: Keine Buchungsdaten (Start/Ende) konnten im Snapshot gefunden werden.
        Opodo: Keine Opodo-Buchungen im HTML gefunden.
        Booking.com: Navigation-Timeout für https://secure.booking.com/mytrips.de.html
        """)
}

@Test func providerID_displayNames_matchProductLabels() throws {
    try withGermanL10n {
        #expect(ProviderID.check24.displayName == "Check24")
        #expect(ProviderID.opodo.displayName == "Opodo")
        #expect(ProviderID.booking.displayName == "Booking.com")
        #expect(ProviderID.airbnb.displayName == "Airbnb")
        #expect(ProviderID.getYourGuide.displayName == "GetYourGuide")
        #expect(ProviderID.traveloka.displayName == "Traveloka")
        #expect(ProviderID.billigerMietwagen.displayName == "billiger-mietwagen.de")
        #expect(ProviderID.manual.displayName == L10n.string(.providerManual))
        for id in ProviderID.syncProviderIDs {
            #expect(!id.displayName.isEmpty)
            #expect(id.displayName != id.rawValue || id == .manual)
        }
    }
}
