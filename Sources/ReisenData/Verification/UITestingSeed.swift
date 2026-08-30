import Foundation
import SwiftData
import ReisenDomain

/// Stabiler In-Memory-Seed für XCUI (`-UITesting`). IDs sind Query-SSOT.
public enum UITestingSeed {
    public static let tripID = makeID("A11C0000-0001-4000-8000-000000000001")
    public static let bookingID = makeID("A11C0000-0001-4000-8000-000000000002")
    public static let tripTitle = "UI Testing Trip"
    public static let bookingTitle = "UI Testing Hotel"

    @MainActor
    public static func insertPopulated(into context: ModelContext) throws {
        let existing = try context.fetch(
            FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripID })
        )
        if !existing.isEmpty { return }

        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(86_400 * 3)
        let trip = SDTrip(
            id: tripID,
            title: tripTitle,
            startDate: start,
            endDate: end,
            destination: "UI-Test"
        )
        context.insert(trip)

        let booking = SDBooking(
            id: bookingID,
            providerRaw: ProviderID.manual.rawValue,
            bookingTypeRaw: BookingType.hotel.rawValue,
            title: bookingTitle,
            startAt: start,
            endAt: start.addingTimeInterval(86_400),
            statusRaw: BookingStatus.confirmed.rawValue,
            trip: trip
        )
        context.insert(booking)
        try context.save()
    }

    private static func makeID(_ value: String) -> UUID {
        guard let id = UUID(uuidString: value) else {
            preconditionFailure("Ungültige stabile UI-Test-ID: \(value)")
        }
        return id
    }
}
