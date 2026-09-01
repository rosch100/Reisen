import Foundation
import SwiftData
import ReisenDomain

public enum SwiftDataAutoGapReconciler {
    public static func reconcile(tripID: UUID, in context: ModelContext) throws {
        let tripDescriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripID })
        guard let trip = try context.fetch(tripDescriptor).first else { return }

        let bookingDescriptor = FetchDescriptor<SDBooking>()
        let allBookings = try context.fetch(bookingDescriptor).filter { $0.trip?.id == tripID }
        let domainBookings = allBookings.map(DomainMapper.booking(from:))

        let suppressDescriptor = FetchDescriptor<SDAutoGapSuppress>(
            predicate: #Predicate { $0.tripID == tripID }
        )
        let suppressed = Set(try context.fetch(suppressDescriptor).map(\.identityKey))

        let diff = ReconcileTripAutoGaps.diff(
            tripStart: trip.startDate,
            tripEnd: trip.endDate,
            allTripBookings: domainBookings,
            suppressedKeys: suppressed
        )

        let deleteIDs = Set(diff.deleteIDs)
        for id in deleteIDs {
            guard let model = allBookings.first(where: { $0.id == id }) else { continue }
            guard model.providerRaw == ProviderID.autoGap.rawValue else { continue }
            context.delete(model)
        }

        let remaining = allBookings.filter { !deleteIDs.contains($0.id) }
        for desired in diff.upserts {
            upsertDesired(desired, trip: trip, existing: remaining, in: context)
        }
    }

    public static func suppress(tripID: UUID, identityKey: String, in context: ModelContext) throws {
        let key = identityKey
        let descriptor = FetchDescriptor<SDAutoGapSuppress>(
            predicate: #Predicate { $0.tripID == tripID && $0.identityKey == key }
        )
        if try context.fetch(descriptor).first != nil { return }
        context.insert(SDAutoGapSuppress(tripID: tripID, identityKey: identityKey))
    }

    private static func upsertDesired(
        _ desired: AutoGapDesired,
        trip: SDTrip,
        existing: [SDBooking],
        in context: ModelContext
    ) {
        let key = desired.identityKey
        let model: SDBooking
        if let found = existing.first(where: {
            $0.providerRaw == ProviderID.autoGap.rawValue && $0.autoGapIdentityKey == key
        }) {
            model = found
        } else {
            model = SDBooking(
                providerRaw: ProviderID.autoGap.rawValue,
                bookingTypeRaw: desired.bookingType.rawValue,
                title: desired.bookingType.defaultDisplayTitle,
                startAt: desired.startAt,
                endAt: desired.endAt,
                locationFrom: desired.locationFrom,
                locationTo: desired.locationTo,
                statusRaw: BookingStatus.unknown.rawValue,
                autoGapIdentityKey: key,
                trip: trip
            )
            context.insert(model)
            return
        }

        guard model.providerRaw == ProviderID.autoGap.rawValue else { return }
        model.bookingTypeRaw = desired.bookingType.rawValue
        model.startAt = desired.startAt
        model.endAt = desired.endAt
        model.locationFrom = desired.locationFrom
        model.locationTo = desired.locationTo
        model.autoGapIdentityKey = key
        model.trip = trip
        if model.title == nil || model.title?.isEmpty == true {
            model.title = desired.bookingType.defaultDisplayTitle
        }
    }
}
