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
    /// Stabile Far-Future-Epoch (~2030-03) — absolut für Gap-Timeline-IDs.
    public static let firstBookingStart = Date(timeIntervalSince1970: 1_900_000_000)
    public static let firstBookingEnd = Date(timeIntervalSince1970: 1_900_086_400)
    public static let secondBookingStart = Date(timeIntervalSince1970: 1_900_172_800)
    public static let secondBookingEnd = Date(timeIntervalSince1970: 1_900_259_200)

    /// Inter-Gap zwischen Seed-Hotel und Seed-Flight (`ComputedGap.timelineItemID`).
    public static var seededGapTimelineItemID: String {
        let start = Int(firstBookingEnd.timeIntervalSince1970)
        let end = Int(secondBookingStart.timeIntervalSince1970)
        let identityKey = "\(bookingID.uuidString)|\(bookingID2.uuidString)|\(start)|\(end)"
        return "gap|\(identityKey)"
    }

    @MainActor
    public static func insertPopulated(into context: ModelContext) throws {
        let existing = try context.fetch(
            FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripID })
        )
        if !existing.isEmpty { return }

        let start = firstBookingStart
        let end = start.addingTimeInterval(86_400 * 3)
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
            startAt: firstBookingStart,
            endAt: firstBookingEnd,
            locationTo: "Berlin",
            statusRaw: BookingStatus.confirmed.rawValue,
            trip: trip
        )
        context.insert(booking)

        // Gleicher Ort wie Hotel → kein Spatial-AutoGap, Inter-Gap bleibt für XCUI sichtbar.
        let booking2 = SDBooking(
            id: bookingID2,
            providerRaw: ProviderID.manual.rawValue,
            bookingTypeRaw: BookingType.flight.rawValue,
            title: bookingTitle2,
            confirmationCode: "UI-TEST-CONF-2",
            startAt: secondBookingStart,
            endAt: secondBookingEnd,
            locationFrom: "Berlin",
            locationTo: "Berlin",
            statusRaw: BookingStatus.confirmed.rawValue,
            trip: trip
        )
        context.insert(booking2)

        // Offene Buchungen im Trip-Fenster, damit Assign-Sheet Candidates hat.
        let openA = SDBooking(
            id: openBookingID,
            providerRaw: ProviderID.manual.rawValue,
            bookingTypeRaw: BookingType.hotel.rawValue,
            title: openBookingTitle,
            confirmationCode: confirmationCode,
            startAt: firstBookingEnd.addingTimeInterval(3_600),
            endAt: firstBookingEnd.addingTimeInterval(7_200),
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
            startAt: firstBookingEnd.addingTimeInterval(10_800),
            endAt: firstBookingEnd.addingTimeInterval(14_400),
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
            startAt: firstBookingEnd.addingTimeInterval(18_000),
            endAt: firstBookingEnd.addingTimeInterval(21_600),
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
