import Foundation
import SwiftData

extension PersistenceBootstrap {
    static func copyCloudEntities(from source: ModelContext, to target: ModelContext) throws {
        let tripByID = try copyTrips(from: source, to: target)
        let bookingByID = try copyBookings(from: source, to: target, tripByID: tripByID)
        try copyGaps(from: source, to: target, tripByID: tripByID, bookingByID: bookingByID)
    }

    static func copyTrips(
        from source: ModelContext,
        to target: ModelContext
    ) throws -> [UUID: SDTrip] {
        let trips = try source.fetch(FetchDescriptor<SDTrip>())
        var tripByID: [UUID: SDTrip] = [:]
        for trip in trips {
            let copy = SDTrip(
                id: trip.id,
                title: trip.title,
                startDate: trip.startDate,
                endDate: trip.endDate,
                destination: trip.destination,
                notes: trip.notes
            )
            target.insert(copy)
            tripByID[copy.id] = copy
        }
        return tripByID
    }

    static func copyGaps(
        from source: ModelContext,
        to target: ModelContext,
        tripByID: [UUID: SDTrip],
        bookingByID: [UUID: SDBooking]
    ) throws {
        let gaps = try source.fetch(FetchDescriptor<SDGap>())
        for gap in gaps {
            let copy = SDGap(
                id: gap.id,
                trip: gap.trip.flatMap { tripByID[$0.id] },
                fromBooking: gap.fromBooking.flatMap { bookingByID[$0.id] },
                toBooking: gap.toBooking.flatMap { bookingByID[$0.id] },
                gapStart: gap.gapStart,
                gapEnd: gap.gapEnd,
                kindRaw: gap.kindRaw,
                titleOverride: gap.titleOverride,
                identityKey: gap.identityKey,
                priceAmount: gap.priceAmount,
                priceCurrencyCode: gap.priceCurrencyCode,
                suggestionStateRaw: gap.suggestionStateRaw
            )
            target.insert(copy)
        }
    }
}
