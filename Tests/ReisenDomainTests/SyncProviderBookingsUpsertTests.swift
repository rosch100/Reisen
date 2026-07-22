import Foundation
import Testing
import ReisenDomain

@MainActor
final class InMemoryBookingRepository: BookingRepository {
    private var storage: [UUID: Booking] = [:]

    init(seed: [Booking] = []) {
        for booking in seed {
            storage[booking.id] = booking
        }
    }

    func fetchAll() throws -> [Booking] {
        Array(storage.values)
    }

    func fetch(id: UUID) throws -> Booking? {
        storage[id]
    }

    func fetch(provider: ProviderID, from startOfDay: Date) throws -> [Booking] {
        storage.values.filter { $0.provider == provider && $0.startAt >= startOfDay }
    }

    func upsert(_ booking: Booking) throws {
        if var existing = storage[booking.id] {
            // Mimic the repository contract after the fix:
            // Upserts coming from sync drafts must not wipe an existing trip assignment.
            if booking.tripID == nil {
                var patched = booking
                patched.tripID = existing.tripID
                storage[booking.id] = patched
            } else {
                storage[booking.id] = booking
            }
        } else {
            storage[booking.id] = booking
        }
    }

    func delete(id: UUID) throws {
        storage.removeValue(forKey: id)
    }

    func deleteProviderBookings(
        provider: ProviderID,
        keepingExternalURLs: Set<String>,
        from startOfDay: Date
    ) throws {
        let toDelete = storage.compactMap { (id, booking) -> UUID? in
            guard booking.provider == provider, booking.startAt >= startOfDay else { return nil }
            guard let url = booking.externalUrl else { return id }
            return keepingExternalURLs.contains(url) ? nil : id
        }
        for id in toDelete {
            storage.removeValue(forKey: id)
        }
    }

    func save() throws {}

    func get(_ id: UUID) -> Booking? {
        storage[id]
    }

    var all: [Booking] { Array(storage.values) }
}

@MainActor
final class SyncProviderBookingsUpsertTests {
    @Test func upsertMatchingByConfirmationCodeKeepsTripAndUpdatesURL() throws {
        let calendar = Calendar.current
        let now = Date(timeIntervalSince1970: 1_700_000_000) // stable test time
        let startOfToday = calendar.startOfDay(for: now)

        let provider = ProviderID.opodo
        let tripID = UUID()
        let bookingID = UUID()

        let existing = Booking(
            id: bookingID,
            provider: provider,
            bookingType: .hotel,
            title: "Hotel",
            confirmationCode: "C1",
            externalUrl: "https://old.example/opodo/1",
            startAt: startOfToday.addingTimeInterval(10 * 24 * 60 * 60),
            endAt: startOfToday.addingTimeInterval(12 * 24 * 60 * 60),
            status: .confirmed,
            tripID: tripID
        )

        let repo = InMemoryBookingRepository(seed: [existing])
        let useCase = SyncProviderBookings(bookingRepository: repo)

        let drafts = [
            ProviderBookingDraft(
                provider: provider,
                bookingType: .hotel,
                title: "Hotel",
                confirmationCode: "C1",
                externalUrl: "https://new.example/opodo/2",
                startAt: existing.startAt,
                endAt: existing.endAt,
                status: .confirmed
            )
        ]

        _ = try useCase.execute(
            provider: provider,
            drafts: drafts,
            requiresDeadlines: false,
            now: now
        )

        #expect(repo.all.count == 1)

        let updated = try #require(repo.get(bookingID))
        #expect(updated.id == bookingID)
        #expect(updated.tripID == tripID)
        #expect(updated.externalUrl == drafts[0].externalUrl)
    }

    @Test func upsertMatchingByDateFingerprintWhenConfirmationCodeIsMissingKeepsTrip() throws {
        let calendar = Calendar.current
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let startOfToday = calendar.startOfDay(for: now)

        let provider = ProviderID.opodo
        let tripID = UUID()
        let bookingID = UUID()

        let existing = Booking(
            id: bookingID,
            provider: provider,
            bookingType: .hotel,
            title: "Hotel",
            confirmationCode: nil,
            externalUrl: "https://old.example/opodo/1",
            startAt: startOfToday.addingTimeInterval(10 * 24 * 60 * 60),
            endAt: startOfToday.addingTimeInterval(12 * 24 * 60 * 60),
            status: .confirmed,
            tripID: tripID
        )

        let repo = InMemoryBookingRepository(seed: [existing])
        let useCase = SyncProviderBookings(bookingRepository: repo)

        let drafts = [
            ProviderBookingDraft(
                provider: provider,
                bookingType: .hotel,
                title: "Hotel",
                confirmationCode: nil,
                externalUrl: "https://new.example/opodo/2",
                startAt: existing.startAt,
                endAt: existing.endAt,
                status: .confirmed
            )
        ]

        _ = try useCase.execute(
            provider: provider,
            drafts: drafts,
            requiresDeadlines: false,
            now: now
        )

        #expect(repo.all.count == 1)

        let updated = try #require(repo.get(bookingID))
        #expect(updated.tripID == tripID)
        #expect(updated.externalUrl == drafts[0].externalUrl)
    }

    @Test func emptyCatalogPrunesFutureProviderBookings() throws {
        let calendar = Calendar.current
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let startOfToday = calendar.startOfDay(for: now)
        let provider = ProviderID.opodo

        let stale = Booking(
            provider: provider,
            bookingType: .hotel,
            title: "Storniert",
            confirmationCode: "X1",
            externalUrl: "https://example/opodo/stale",
            startAt: startOfToday.addingTimeInterval(10 * 24 * 60 * 60),
            endAt: startOfToday.addingTimeInterval(12 * 24 * 60 * 60),
            status: .confirmed
        )
        let repo = InMemoryBookingRepository(seed: [stale])
        let useCase = SyncProviderBookings(bookingRepository: repo)

        let result = try useCase.execute(
            provider: provider,
            drafts: [],
            requiresDeadlines: true,
            now: now
        )

        #expect(result.bookingsPersisted == 0)
        #expect(repo.all.isEmpty)
    }

    @Test func missingDeadlinesStillPrunesAbsentBookings() throws {
        let calendar = Calendar.current
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let startOfToday = calendar.startOfDay(for: now)
        let provider = ProviderID.opodo

        let keptStart = startOfToday.addingTimeInterval(10 * 24 * 60 * 60)
        let keptEnd = startOfToday.addingTimeInterval(12 * 24 * 60 * 60)
        let kept = Booking(
            provider: provider,
            bookingType: .hotel,
            title: "Bleibt",
            confirmationCode: "K1",
            externalUrl: "https://example/opodo/keep",
            startAt: keptStart,
            endAt: keptEnd,
            status: .confirmed
        )
        let cancelled = Booking(
            provider: provider,
            bookingType: .hotel,
            title: "Weg",
            confirmationCode: "C1",
            externalUrl: "https://example/opodo/gone",
            startAt: startOfToday.addingTimeInterval(20 * 24 * 60 * 60),
            endAt: startOfToday.addingTimeInterval(22 * 24 * 60 * 60),
            status: .confirmed
        )
        let repo = InMemoryBookingRepository(seed: [kept, cancelled])
        let useCase = SyncProviderBookings(bookingRepository: repo)

        let drafts = [
            ProviderBookingDraft(
                provider: provider,
                bookingType: .hotel,
                title: "Bleibt",
                confirmationCode: "K1",
                externalUrl: "https://example/opodo/keep",
                startAt: keptStart,
                endAt: keptEnd,
                status: .confirmed,
                deadlines: []
            )
        ]

        // Katalog-Reconciliation darf nicht an fehlenden Fristen scheitern.
        let result = try useCase.execute(
            provider: provider,
            drafts: drafts,
            requiresDeadlines: false,
            now: now
        )

        #expect(result.bookingsPersisted == 1)
        #expect(repo.all.count == 1)
        #expect(repo.all.first?.externalUrl == "https://example/opodo/keep")
    }

    @Test func cancelledDraftsDoNotRequireDeadlines() throws {
        let calendar = Calendar.current
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let startOfToday = calendar.startOfDay(for: now)
        let provider = ProviderID.opodo

        let repo = InMemoryBookingRepository()
        let useCase = SyncProviderBookings(bookingRepository: repo)

        let drafts = [
            ProviderBookingDraft(
                provider: provider,
                bookingType: .hotel,
                title: "Storno",
                confirmationCode: "S1",
                externalUrl: "https://example/opodo/cancelled",
                startAt: startOfToday.addingTimeInterval(10 * 24 * 60 * 60),
                endAt: startOfToday.addingTimeInterval(12 * 24 * 60 * 60),
                status: .cancelled,
                deadlines: []
            )
        ]

        let result = try useCase.execute(
            provider: provider,
            drafts: drafts,
            requiresDeadlines: true,
            now: now
        )

        #expect(result.bookingsPersisted == 1)
        #expect(repo.all.count == 1)
        #expect(repo.all.first?.status == .cancelled)
    }

    @Test func upsertWithNilTripIDDoesNotWipeExistingTripInRepositorySemantics() throws {
        let provider = ProviderID.opodo
        let tripID = UUID()
        let bookingID = UUID()

        let existing = Booking(
            id: bookingID,
            provider: provider,
            bookingType: .hotel,
            title: "Hotel",
            confirmationCode: nil,
            externalUrl: "https://example/opodo/1",
            startAt: Date(timeIntervalSince1970: 1_700_000_100),
            endAt: Date(timeIntervalSince1970: 1_700_000_200),
            status: .confirmed,
            tripID: tripID
        )

        let repo = InMemoryBookingRepository(seed: [existing])

        // Upsert a sync draft that doesn't carry trip assignment.
        var draftBooking = existing
        draftBooking.tripID = nil

        try repo.upsert(draftBooking)

        let updated = try #require(repo.get(bookingID))
        #expect(updated.tripID == tripID)
    }
}

