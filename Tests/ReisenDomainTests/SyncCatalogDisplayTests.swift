import Foundation
import Testing
import ReisenDomain

private let sampleStart = Date(timeIntervalSince1970: 1_700_000_000)
private let sampleEnd = Date(timeIntervalSince1970: 1_700_086_400)

@Test func providerBookingDraft_partitionedByCancellation() {
    let drafts = [
        ProviderBookingDraft(
            provider: .check24,
            bookingType: .hotel,
            startAt: sampleStart,
            endAt: sampleEnd,
            status: .confirmed
        ),
        ProviderBookingDraft(
            provider: .check24,
            bookingType: .flight,
            startAt: sampleStart,
            endAt: sampleEnd,
            status: .cancelled
        ),
        ProviderBookingDraft(
            provider: .check24,
            bookingType: .hotel,
            startAt: sampleStart,
            endAt: sampleEnd,
            status: .unknown
        ),
    ]

    let (active, cancelledCount) = drafts.partitionedByCancellation()

    #expect(cancelledCount == 1)
    #expect(active.count == 2)
    #expect(active.allSatisfy { $0.status != .cancelled })
}

@Test func providerBookingDraft_missingDeadlinesHint_whenRequiredAndEmpty() {
    let drafts = [
        ProviderBookingDraft(
            provider: .booking,
            bookingType: .hotel,
            startAt: sampleStart,
            endAt: sampleEnd,
            status: .confirmed
        ),
        ProviderBookingDraft(
            provider: .booking,
            bookingType: .flight,
            startAt: sampleStart,
            endAt: sampleEnd,
            status: .confirmed
        ),
    ]

    #expect(drafts.missingDeadlinesHint(requiresDeadlines: true))
    #expect(!drafts.missingDeadlinesHint(requiresDeadlines: false))
}

@Test func providerBookingDraft_missingDeadlinesHint_falseWhenDeadlinesPresent() {
    var draft = ProviderBookingDraft(
        provider: .booking,
        bookingType: .hotel,
        startAt: sampleStart,
        endAt: sampleEnd,
        status: .confirmed
    )
    draft.deadlines = [
        CancellationDeadline(
            deadlineAt: sampleStart,
            isFreeCancellation: true
        ),
    ]

    #expect(![draft].missingDeadlinesHint(requiresDeadlines: true))
}

@Test func syncProviderBookingsResult_persistedSyncStatusLine() {
    L10n.locale = Locale(identifier: "de")
    defer { L10n.locale = .current }

    let stats = SyncProviderBookingsResult(bookingsPersisted: 3, deadlinesPersisted: 2)

    #expect(stats.persistedSyncStatusLine(missingDeadlinesHint: false)
        == L10n.format(.syncResultCompleted, 3, 2))
    #expect(stats.persistedSyncStatusLine(missingDeadlinesHint: true)
        == L10n.format(.syncResultCompletedMissingDeadlines, 3))
}

@Test func booking_displayTitle_andLookup() {
    let withTitle = Booking(
        provider: .check24,
        bookingType: .hotel,
        title: "Hotel Alpha",
        startAt: sampleStart,
        endAt: sampleEnd
    )
    let withoutTitle = Booking(
        provider: .check24,
        bookingType: .flight,
        startAt: sampleStart,
        endAt: sampleEnd
    )

    #expect(withTitle.displayTitle == "Hotel Alpha")
    #expect(withoutTitle.displayTitle == BookingType.flight.defaultDisplayTitle)
    #expect(withTitle.displayTitle(using: [:]) == "Hotel Alpha")
    #expect(withoutTitle.displayTitle(using: [withoutTitle.id: "Override"]) == "Override")
}
