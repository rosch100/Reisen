import Testing
import Foundation
import ReisenOpodo
import ReisenDomain

/// End-to-End: HAR-Katalog + Hotel-Storno-Enrichment → Sync → persistierte Buchungsfelder.
@MainActor
struct OpodoSyncPersistenceTests {
    @Test("Opodo HAR: aktive Buchungen + Stornofristen landen vollständig in der DB")
    func opodoHARBookingsPersistWithDeadlinesAndCatalogFields() throws {
        let catalogJSON = try fixtureJSON("getTrips_upcoming.json")
        var drafts = try OpodoTripsGraphQLParser().parseTrips(from: catalogJSON)
        #expect(drafts.count == 3)

        // Wie SyncStore: Storno-Status aus Katalog, Stornofristen per getTripByToken (HAR Merlynn).
        let merlynnIndex = try #require(drafts.firstIndex { $0.title?.contains("Merlynn") == true })
        let cancelJSON = """
        {
          "data": {
            "getTrip": {
              "trip": {
                "bookingStatus": "CONTRACT",
                "bookingProductStatus": "CONFIRMED",
                "accommodationBooking": { "bookingStatus": "CONTRACT" },
                "accommodationProductBooking": {
                  "cancellationPolicies": {
                    "cancellableStatus": "REFUNDABLE",
                    "cancellationOptions": [
                      {
                        "from": "2026-07-18T12:00:00+02:00",
                        "until": "2026-08-17T05:59:00+02:00",
                        "refundAmount": { "amount": 63.0, "currency": "EUR" },
                        "refundPercentage": 100
                      },
                      {
                        "from": "2026-08-17T06:00:00+02:00",
                        "until": "2026-08-21T00:00:00+02:00",
                        "refundAmount": { "amount": 0.0, "currency": "EUR" },
                        "refundPercentage": 0
                      }
                    ]
                  }
                }
              }
            }
          }
        }
        """
        let enrichment = try OpodoTripCancellationGraphQLParser().parse(from: cancelJSON)
        drafts[merlynnIndex].deadlines = enrichment.deadlines
        drafts[merlynnIndex].hotelOffsetSeconds =
            enrichment.deadlines.compactMap(\.hotelOffsetSeconds).first ?? 0
        if let status = enrichment.status {
            drafts[merlynnIndex].status = status
        }

        let cancelled = drafts.filter { $0.status == .cancelled }
        #expect(cancelled.count == 1)
        #expect(cancelled.first?.title?.contains("Plataran") == true)

        // SyncStore übergibt nur aktive Drafts; Stornos werden lokal entfernt.
        let activeDrafts = drafts.filter { $0.status != .cancelled }
        #expect(activeDrafts.count == 2)

        let repo = OpodoInMemoryBookingRepository()
        let useCase = SyncProviderBookings(bookingRepository: repo)
        let now = Date(timeIntervalSince1970: 1_753_000_000) // 2025-07-20 — vor den HAR-Reisedaten
        let result = try useCase.execute(
            provider: .opodo,
            drafts: activeDrafts,
            requiresDeadlines: true,
            now: now
        )
        #expect(result.bookingsPersisted == 2)
        #expect(result.deadlinesPersisted >= 1)

        let stored = try repo.fetchAll().sorted { $0.startAt < $1.startAt }
        #expect(stored.count == 2)
        #expect(stored.allSatisfy { $0.status != .cancelled })

        let flight = try #require(stored.first { $0.bookingType == .flight })
        #expect(flight.title == "Singapur → Jakarta")
        #expect(flight.confirmationCode == "1D9505")
        #expect(flight.locationFrom == "Singapur (SIN)")
        #expect(flight.locationTo == "Jakarta (CGK)")
        #expect(flight.locationFromAddress == "Singapore Changi Airport")
        #expect(flight.locationToAddress == "Soekarno-Hatta International Airport")
        #expect(flight.status == .confirmed)
        #expect(flight.rateDetails?.totalPriceAmount == 333.79)
        #expect(flight.rateDetails?.totalPriceCurrency == "EUR")
        #expect(flight.rateDetails?.airline == "TransNusa")
        #expect(flight.rateDetails?.passengerCount == 3)
        #expect(flight.externalUrl?.contains("#tripdetails/td=") == true)
        #expect(flight.cancellationDeadlines.isEmpty)

        let hotel = try #require(stored.first { $0.bookingType == .hotel })
        #expect(hotel.title == "Merlynn Park Hotel")
        #expect(hotel.confirmationCode == "100172774666")
        #expect(hotel.locationTo == "Jakarta")
        #expect(hotel.locationToAddress == "Jl. KH. Hasyim Azhari 29 - 31, 10130 Jakarta, ID")
        #expect(hotel.status == .confirmed)
        #expect(hotel.hotelCheckInMinutes == 14 * 60)
        #expect(hotel.hotelCheckOutMinutes == 12 * 60)
        #expect(hotel.hotelOffsetSeconds == 2 * 3600)
        #expect(hotel.rateDetails?.totalPriceAmount == 63.0)
        #expect(hotel.rateDetails?.boardType == .breakfastIncluded)
        #expect(hotel.rateDetails?.includedBreakfast == true)
        #expect(hotel.rateDetails?.roomCount == 1)
        #expect(hotel.rateDetails?.guestCount == 3)
        #expect(hotel.rateDetails?.roomCategory == "Family Suite")
        #expect(hotel.cancellationDeadlines.contains { $0.isFreeCancellation })
        let free = try #require(hotel.cancellationDeadlines.first { $0.isFreeCancellation })
        #expect(free.policyText?.contains("Stornierungsrichtlinie") == true)
        #expect(free.hotelOffsetSeconds == 2 * 3600)
    }
}

@MainActor
private final class OpodoInMemoryBookingRepository: BookingRepository {
    private var storage: [UUID: Booking] = [:]

    func fetchAll() throws -> [Booking] { Array(storage.values) }
    func fetch(id: UUID) throws -> Booking? { storage[id] }

    func fetch(provider: ProviderID, from startOfDay: Date) throws -> [Booking] {
        storage.values.filter { $0.provider == provider && $0.startAt >= startOfDay }
    }

    func upsert(_ booking: Booking) throws {
        storage[booking.id] = booking
    }

    func delete(id: UUID) throws {
        storage.removeValue(forKey: id)
    }

    func deleteProviderBookings(
        provider: ProviderID,
        keepingExternalURLs: Set<String>,
        from startOfDay: Date
    ) throws {
        let ids = storage.compactMap { id, booking -> UUID? in
            guard booking.provider == provider, booking.startAt >= startOfDay else { return nil }
            guard let url = booking.externalUrl else { return id }
            return keepingExternalURLs.contains(url) ? nil : id
        }
        for id in ids { storage.removeValue(forKey: id) }
    }

    func save() throws {}
}

private func fixtureJSON(_ name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
    return try String(contentsOf: url, encoding: .utf8)
}
