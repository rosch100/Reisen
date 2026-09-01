import Foundation

public struct AutoGapReconcileDiff: Equatable, Sendable {
    public var upserts: [AutoGapDesired]
    public var deleteIDs: [UUID]
    public var skippedSuppressed: Int

    public init(upserts: [AutoGapDesired], deleteIDs: [UUID], skippedSuppressed: Int) {
        self.upserts = upserts
        self.deleteIDs = deleteIDs
        self.skippedSuppressed = skippedSuppressed
    }

    public static func compute(
        desired: [AutoGapDesired],
        existingAuto: [Booking],
        suppressedKeys: Set<String>
    ) -> AutoGapReconcileDiff {
        var upserts: [AutoGapDesired] = []
        var skipped = 0
        var desiredKeys = Set<String>()

        for item in desired {
            desiredKeys.insert(item.identityKey)
            if suppressedKeys.contains(item.identityKey) {
                skipped += 1
                continue
            }
            upserts.append(item)
        }

        let deleteIDs = existingAuto.compactMap { booking -> UUID? in
            guard booking.isAutoGap else { return nil }
            guard let key = booking.autoGapIdentityKey else { return booking.id }
            if suppressedKeys.contains(key) { return booking.id }
            if !desiredKeys.contains(key) { return booking.id }
            return nil
        }

        return AutoGapReconcileDiff(upserts: upserts, deleteIDs: deleteIDs, skippedSuppressed: skipped)
    }
}

public enum ReconcileTripAutoGaps {
    public static func diff(
        tripStart: Date,
        tripEnd: Date,
        allTripBookings: [Booking],
        suppressedKeys: Set<String>
    ) -> AutoGapReconcileDiff {
        let desired = AutoGapPlanner.plan(
            tripStart: tripStart,
            tripEnd: tripEnd,
            bookings: allTripBookings
        )
        let existingAuto = allTripBookings.filter(\.isAutoGap)
        return AutoGapReconcileDiff.compute(
            desired: desired,
            existingAuto: existingAuto,
            suppressedKeys: suppressedKeys
        )
    }
}
