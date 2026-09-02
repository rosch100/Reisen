import Foundation
import SwiftData
import ReisenDomain

/// Stabiler In-Memory-Seed für XCUI (`-UITesting`). IDs sind Query-SSOT.
public enum UITestingSeed {
    public static let tripID = makeID("A11C0000-0001-4000-8000-000000000001")
    public static let bookingID = makeID("A11C0000-0001-4000-8000-000000000002")
    public static let bookingID2 = makeID("A11C0000-0001-4000-8000-000000000003")
    public static let tripID2 = makeID("A11C0000-0001-4000-8000-000000000004")
    public static let openBookingID = makeID("A11C0000-0001-4000-8000-000000000005")
    public static let openBookingID2 = makeID("A11C0000-0001-4000-8000-000000000006")
    public static let openBookingID3 = makeID("A11C0000-0001-4000-8000-000000000007")
    public static let tripTitle = "UI Testing Trip"
    public static let tripTitle2 = "UI Testing Trip B"
    public static let bookingTitle = "UI Testing Hotel"
    public static let bookingTitle2 = "UI Testing Flight"
    public static let openBookingTitle = "UI Testing Open A"
    public static let openBookingTitle2 = "UI Testing Open B"
    public static let openBookingTitle3 = "UI Testing Open C"
    public static let confirmationCode = "UI-TEST-CONF"

    @MainActor
    public static func insertPopulated(into context: ModelContext) throws {
        let existing = try context.fetch(
            FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripID })
        )
        if !existing.isEmpty { return }

        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(86_400 * 3)
        let openBookingReference = Calendar.current.startOfDay(for: Date())
        let trip = SDTrip(
            id: tripID,
            title: tripTitle,
            startDate: start,
            endDate: end,
            destination: "UI-Test"
        )
        context.insert(trip)

        let trip2Start = start.addingTimeInterval(86_400 * 30)
        let trip2 = SDTrip(
            id: tripID2,
            title: tripTitle2,
            startDate: trip2Start,
            endDate: trip2Start.addingTimeInterval(86_400 * 2),
            destination: "UI-Test-B"
        )
        context.insert(trip2)

        let booking = SDBooking(
            id: bookingID,
            providerRaw: ProviderID.manual.rawValue,
            bookingTypeRaw: BookingType.hotel.rawValue,
            title: bookingTitle,
            confirmationCode: confirmationCode,
            startAt: start,
            endAt: start.addingTimeInterval(86_400),
            statusRaw: BookingStatus.confirmed.rawValue,
            trip: trip
        )
        context.insert(booking)

        let booking2 = SDBooking(
            id: bookingID2,
            providerRaw: ProviderID.manual.rawValue,
            bookingTypeRaw: BookingType.flight.rawValue,
            title: bookingTitle2,
            confirmationCode: "UI-TEST-CONF-2",
            startAt: start.addingTimeInterval(86_400),
            endAt: start.addingTimeInterval(86_400 * 2),
            statusRaw: BookingStatus.confirmed.rawValue,
            trip: trip
        )
        context.insert(booking2)

        let openA = SDBooking(
            id: openBookingID,
            providerRaw: ProviderID.manual.rawValue,
            bookingTypeRaw: BookingType.hotel.rawValue,
            title: openBookingTitle,
            confirmationCode: confirmationCode,
            startAt: openBookingReference.addingTimeInterval(86_400 * 10),
            endAt: openBookingReference.addingTimeInterval(86_400 * 11),
            statusRaw: BookingStatus.confirmed.rawValue,
            trip: nil
        )
        context.insert(openA)

        let openB = SDBooking(
            id: openBookingID2,
            providerRaw: ProviderID.manual.rawValue,
            bookingTypeRaw: BookingType.hotel.rawValue,
            title: openBookingTitle2,
            confirmationCode: "UI-TEST-OPEN-B",
            startAt: openBookingReference.addingTimeInterval(86_400 * 12),
            endAt: openBookingReference.addingTimeInterval(86_400 * 13),
            statusRaw: BookingStatus.confirmed.rawValue,
            trip: nil
        )
        context.insert(openB)

        let openC = SDBooking(
            id: openBookingID3,
            providerRaw: ProviderID.manual.rawValue,
            bookingTypeRaw: BookingType.hotel.rawValue,
            title: openBookingTitle3,
            confirmationCode: "UI-TEST-OPEN-C",
            startAt: openBookingReference.addingTimeInterval(86_400 * 14),
            endAt: openBookingReference.addingTimeInterval(86_400 * 15),
            statusRaw: BookingStatus.confirmed.rawValue,
            trip: nil
        )
        context.insert(openC)

        try context.save()
    }

    private static func makeID(_ value: String) -> UUID {
        guard let id = UUID(uuidString: value) else {
            preconditionFailure("Ungültige stabile UI-Test-ID: \(value)")
        }
        return id
    }
}
