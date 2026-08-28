import Foundation
import ReisenDomain

extension BilligerMietwagenBookingDetailParser {
    private static let secondsPerHour: TimeInterval = 3_600

    /// Portal-SSOT `reservation.cancelUntil`, sonst Stunden vor Abholung.
    static func cancellationDeadlines(
        cancelUntil: String?,
        freeCancellation: Bool,
        freeCancellationHours: Int?,
        pickUpDateTime: String?,
        catalogStartAt: Date?,
        hotelOffsetSeconds: Int?
    ) -> [CancellationDeadline] {
        if let deadline = deadlineFromCancelUntil(
            cancelUntil,
            freeCancellation: freeCancellation,
            hotelOffsetSeconds: hotelOffsetSeconds
        ) {
            return [deadline]
        }
        if let deadline = deadlineFromFreeHours(
            freeCancellation: freeCancellation,
            hours: freeCancellationHours,
            pickUpDateTime: pickUpDateTime,
            catalogStartAt: catalogStartAt,
            hotelOffsetSeconds: hotelOffsetSeconds
        ) {
            return [deadline]
        }
        return []
    }

    private static func deadlineFromCancelUntil(
        _ raw: String?,
        freeCancellation: Bool,
        hotelOffsetSeconds: Int?
    ) -> CancellationDeadline? {
        guard let raw = NonEmpty.string(raw) else { return nil }

        if let instant = ISODateTime.parseInstant(raw) {
            return makeDeadline(
                at: instant,
                freeCancellation: freeCancellation,
                offsetSeconds: resolvedOffset(fromISO: raw, catalogOffset: hotelOffsetSeconds)
            )
        }

        // Wall-Clock ohne Offset → Instant mit Katalog-/Pickup-Offset (kein erfundenes UTC).
        guard let wall = ISODateTime.parseWallClockUTC(raw),
              let offset = hotelOffsetSeconds
        else {
            return nil
        }
        return makeDeadline(
            at: wall.addingTimeInterval(TimeInterval(-offset)),
            freeCancellation: freeCancellation,
            offsetSeconds: offset
        )
    }

    private static func deadlineFromFreeHours(
        freeCancellation: Bool,
        hours: Int?,
        pickUpDateTime: String?,
        catalogStartAt: Date?,
        hotelOffsetSeconds: Int?
    ) -> CancellationDeadline? {
        guard freeCancellation, let hours, hours > 0 else { return nil }
        guard let start = pickupStart(pickUpDateTime: pickUpDateTime, catalogStartAt: catalogStartAt) else {
            return nil
        }
        // API-Stunden = feste Dauer (nicht Calendar/DST der Geräte-TZ).
        return makeDeadline(
            at: start.addingTimeInterval(-TimeInterval(hours) * secondsPerHour),
            freeCancellation: true,
            offsetSeconds: resolvedOffset(fromISO: pickUpDateTime, catalogOffset: hotelOffsetSeconds)
        )
    }

    /// ISO-String-Offset vor Katalog-Offset (eine Prioritätsregel für alle Fristen).
    private static func resolvedOffset(fromISO raw: String?, catalogOffset: Int?) -> Int? {
        ISODateTime.offsetSeconds(from: raw) ?? catalogOffset
    }

    /// Detail-Pickup mit Offset, sonst Katalog-`startAt`.
    private static func pickupStart(pickUpDateTime: String?, catalogStartAt: Date?) -> Date? {
        BilligerMietwagenJSON.parseISODate(pickUpDateTime) ?? catalogStartAt
    }

    private static func makeDeadline(
        at deadlineAt: Date,
        freeCancellation: Bool,
        offsetSeconds: Int?
    ) -> CancellationDeadline {
        CancellationDeadline(
            deadlineAt: deadlineAt,
            policyText: freeCancellation ? nil : "Stornierung bis zum angegebenen Zeitpunkt",
            isFreeCancellation: freeCancellation,
            hotelOffsetSeconds: offsetSeconds
        )
    }
}
