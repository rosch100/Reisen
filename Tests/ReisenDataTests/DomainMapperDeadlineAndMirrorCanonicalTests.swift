import Foundation
import Testing
import SwiftData
import ReisenData
import ReisenDomain

@MainActor
@Suite("DomainMapper deadlines")
struct DomainMapperDeadlineEpochTests {
    @Test("epoch-zero deadlineAt is omitted")
    func epochZeroIsInvalid() throws {
        let schema = Schema([SDCancellationDeadline.self, SDBooking.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let booking = SDBooking(
            providerRaw: ProviderID.opodo.rawValue,
            bookingTypeRaw: BookingType.hotel.rawValue,
            title: "Hotel",
            startAt: Date(timeIntervalSince1970: 1_700_000_000),
            endAt: Date(timeIntervalSince1970: 1_700_086_400),
            statusRaw: BookingStatus.confirmed.rawValue
        )
        context.insert(booking)

        let invalid = SDCancellationDeadline(
            deadlineAt: Date(timeIntervalSince1970: 0),
            isFreeCancellation: true,
            booking: booking
        )
        let valid = SDCancellationDeadline(
            deadlineAt: Date(timeIntervalSince1970: 1_699_000_000),
            isFreeCancellation: true,
            booking: booking
        )
        context.insert(invalid)
        context.insert(valid)
        booking.cancellationDeadlines = [invalid, valid]
        try context.save()

        #expect(DomainMapper.deadline(from: invalid) == nil)
        #expect(DomainMapper.deadline(from: valid) != nil)
        #expect(booking.domainCancellationDeadlines.count == 1)
        #expect(booking.domainCancellationDeadlines.first?.deadlineAt.timeIntervalSince1970 == 1_699_000_000)
    }
}

@MainActor
@Suite("ProviderPreferencesMirror canonical")
struct ProviderPreferencesMirrorCanonicalTests {
    @Test("fetchCanonical ignores non-singleton rows")
    func fetchCanonicalIgnoresStray() throws {
        let schema = Schema([SDProviderPreferences.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let stray = SDProviderPreferences()
        stray.id = UUID()
        stray.setupCompleted = true
        context.insert(stray)
        try context.save()

        #expect(try ProviderPreferencesMirror.fetchCanonical(in: context) == nil)
    }

    @Test("cloudkit await disabled returns disabled")
    func cloudKitAwaitDisabled() async {
        let result = await PersistenceBootstrap.awaitCloudKitImportIfNeeded(
            timeout: .milliseconds(10),
            cloudKitEnabled: false
        )
        #expect(result == .disabled)
    }
}
