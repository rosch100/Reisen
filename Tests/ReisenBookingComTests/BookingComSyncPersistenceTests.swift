import Testing
import Foundation
import ReisenDomain
import ReisenBookingCom

/// End-to-End (no webview): order JSON → enrichment mapping → SyncProviderBookings → persistence semantics.
@MainActor
struct BookingComSyncPersistenceTests {
    @Test("Booking.com Flight Sync persistiert strukturierte Passagiere + Gepäck in den Bookings")
    func bookingComFlightPassengersPersisted() throws {
        let orderJSON = """
        {
          "cancellationOptions": {
            "cancellable": false,
            "isFullRefund": false,
            "refundOptions": [],
            "cancellationStatus": "UNKNOWN_CANCELLABLE",
            "flightsPbemUniversalNonRefundableOrders": false
          },
          "airOrder": {
            "flightSegments": [
              {
                "departureTimeTz": "2026-08-11T16:10:00+07:00",
                "arrivalTimeTz": "2026-08-11T18:35:00+08:00",
                "travellerCheckedLuggage": [
                  {
                    "travellerReference": "T1",
                    "luggageAllowance": {
                      "luggageType": "CHECKED_IN",
                      "ruleType": "PIECE_BASED",
                      "maxPiece": 1,
                      "maxWeightPerPiece": 10,
                      "massUnit": "KG"
                    }
                  }
                ],
                "travellerCabinLuggage": [
                  {
                    "travellerReference": "T1",
                    "luggageAllowance": {
                      "luggageType": "HAND",
                      "maxPiece": 1,
                      "maxWeightPerPiece": 5,
                      "massUnit": "KG",
                      "sizeRestrictions": { "maxLength": 40, "maxWidth": 30, "maxHeight": 20, "sizeUnit": "CM" }
                    },
                    "personalItem": true
                  }
                ]
              }
            ]
          },
          "passengers": [
            { "travellerReference": "T1", "firstName": "Roland", "lastName": "Schramme", "type": "ADULT" }
          ],
          "orderId": "x",
          "orderToken": "y",
          "orderStatus": "CONFIRMED",
          "isCancellableWithin24Hours": false,
          "publicReference": { "prefix": 0, "number": 0, "pin": "", "publicReference": "", "formattedReference": "" },
          "totalPrice": { "total": { "currencyCode": "EUR", "units": 0, "nanos": 0 } },
          "luggageBySegment": []
        }
        """

        let parsed = try BookingComFlightOrderParser().parse(from: orderJSON)
        #expect(parsed.passengers.count == 1)

        let departure = Date(timeIntervalSince1970: 1_785_000_000)
        let arrival = departure.addingTimeInterval(2 * 3600)

        let passengers = parsed.passengers
        let draft = ProviderBookingDraft(
            provider: .booking,
            bookingType: .flight,
            title: "Test Flight",
            confirmationCode: "SSPCR",
            externalUrl: "https://flights.booking.com/confirmation/testtoken",
            startAt: departure,
            endAt: arrival,
            locationFrom: "YIA (Yogyakarta)",
            locationTo: "DPS (Kuta)",
            locationFromAddress: nil,
            locationToAddress: nil,
            status: .confirmed,
            deadlines: parsed.deadlines,
            rateDetails: parsed.rateDetails,
            hotelOffsetSeconds: nil,
            hotelCheckInMinutes: nil,
            hotelCheckOutMinutes: nil,
            flightDepartureOffsetSeconds: parsed.flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: parsed.flightArrivalOffsetSeconds,
            rawPayloadFingerprint: nil,
            passengers: passengers
        )

        let repo = BookingComInMemoryBookingRepository()
        let useCase = SyncProviderBookings(bookingRepository: repo)

        let result = try useCase.execute(
            provider: .booking,
            drafts: [draft],
            requiresDeadlines: false,
            now: departure
        )
        #expect(result.bookingsPersisted == 1)

        let stored = try repo.fetchAll()
        #expect(stored.count == 1)
        guard let booking = stored.first else { return }

        #expect(booking.passengers.count == 1)
        let pax = booking.passengers.first!
        #expect(pax.givenName == "Roland")
        #expect(pax.familyName == "Schramme")

        // Gepäck pro Reisenden:
        #expect(pax.baggageAllowances.contains { $0.type == .checkedBag && $0.pieceCount == 1 && $0.weightKg == 10 })
        #expect(pax.baggageAllowances.contains { $0.type == .cabinBag && $0.pieceCount == 1 && $0.weightKg == 5 })
        #expect(pax.baggageAllowances.contains { $0.type == .personalItem })

        // rateDetails werden ebenfalls persistiert (Gepäcksummary als Raw-String).
        #expect(booking.rateDetails?.baggageInfoRaw?.contains("Aufgabe") == true)
        #expect(booking.rateDetails?.baggageInfoRaw?.contains("Hand") == true)
    }
}

@MainActor
private final class BookingComInMemoryBookingRepository: BookingRepository {
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

