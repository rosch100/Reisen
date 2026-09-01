import Foundation
import SwiftData
import ReisenDomain
import ReisenData

public struct GapEditorPayload: Identifiable, Equatable {
    public var id: String { key }
    public let key: String
    public let kind: GapKind
    public let title: String
    public let priceAmount: Double?
    public let priceCurrencyCode: String?
    public let gapStart: Date
    public let gapEnd: Date
    public let fromBookingID: UUID
    public let toBookingID: UUID
    public let fromLocationFrom: String?
    public let fromLocationTo: String?
    public let toLocationFrom: String?
    public let toLocationTo: String?

    public init(
        key: String,
        kind: GapKind,
        title: String,
        priceAmount: Double?,
        priceCurrencyCode: String?,
        gapStart: Date,
        gapEnd: Date,
        fromBookingID: UUID,
        toBookingID: UUID,
        fromLocationFrom: String? = nil,
        fromLocationTo: String? = nil,
        toLocationFrom: String? = nil,
        toLocationTo: String? = nil
    ) {
        self.key = key
        self.kind = kind
        self.title = title
        self.priceAmount = priceAmount
        self.priceCurrencyCode = priceCurrencyCode
        self.gapStart = gapStart
        self.gapEnd = gapEnd
        self.fromBookingID = fromBookingID
        self.toBookingID = toBookingID
        self.fromLocationFrom = fromLocationFrom
        self.fromLocationTo = fromLocationTo
        self.toLocationFrom = toLocationFrom
        self.toLocationTo = toLocationTo
    }

    public func gapContext(kind: GapKind) -> GapContext {
        GapContext(
            gapStart: gapStart,
            gapEnd: gapEnd,
            kind: kind,
            fromLocationFrom: fromLocationFrom,
            fromLocationTo: fromLocationTo,
            toLocationFrom: toLocationFrom,
            toLocationTo: toLocationTo
        )
    }
}

/// Anzeige-Auflösung: persistiertes `SDGap` vor ComputedGap-Defaults.
public struct GapPresentation: Equatable {
    public let key: String
    public let displayTitle: String
    public let effectiveKind: GapKind
    public let priceAmount: Double?
    public let priceCurrencyCode: String?

    public var priceText: String? {
        guard let priceAmount else { return nil }
        return Formatting.formatCurrencyAmount(priceAmount, currencyCode: priceCurrencyCode)
    }

    public static func resolve(computed: ComputedGap, saved: SDGap?) -> GapPresentation {
        GapPresentation(
            key: computed.identityKey,
            displayTitle: saved?.titleOverride ?? Self.defaultDisplayTitle(for: computed),
            effectiveKind: saved?.kind ?? computed.kind,
            priceAmount: saved?.priceAmount,
            priceCurrencyCode: saved?.priceCurrencyCode
        )
    }

    /// Transport-Lücken: Kind + Start-/Zielstadt, wenn ableitbar.
    private static func defaultDisplayTitle(for gap: ComputedGap) -> String {
        let base = gap.kind.defaultDisplayTitle
        guard gap.kind == .transport else { return base }
        guard let from = SpatialGapDetector.fromEndPlace(gap.fromBooking),
              let to = SpatialGapDetector.toStartPlace(gap.toBooking)
        else { return base }
        return "\(base) · \(from) → \(to)"
    }

    public func editorPayload(for gap: ComputedGap) -> GapEditorPayload {
        GapEditorPayload(
            key: key,
            kind: effectiveKind,
            title: displayTitle,
            priceAmount: priceAmount,
            priceCurrencyCode: priceCurrencyCode,
            gapStart: gap.gapStart,
            gapEnd: gap.gapEnd,
            fromBookingID: gap.fromBooking.id,
            toBookingID: gap.toBooking.id,
            fromLocationFrom: gap.fromBooking.locationFrom,
            fromLocationTo: gap.fromBooking.locationTo,
            toLocationFrom: gap.toBooking.locationFrom,
            toLocationTo: gap.toBooking.locationTo
        )
    }
}

/// Gemeinsame Gap-Auflösung für macOS-TripDetail und `TripTimelineSection`.
public enum TripGapTimeline {
    public static func savedGapsByKey(allGaps: [SDGap], tripID: UUID) -> [String: SDGap] {
        Dictionary(
            uniqueKeysWithValues: allGaps
                .filter { $0.trip?.id == tripID }
                .compactMap { gap -> (String, SDGap)? in
                    guard let key = gap.identityKey, !key.isEmpty else { return nil }
                    return (key, gap)
                }
        )
    }

    public static func computedGaps(trip: SDTrip, bookings: [SDBooking]) -> [ComputedGap] {
        GapDetector().computeGaps(
            bookings: bookings.map(DomainMapper.booking(from:)),
            tripStart: trip.startDate,
            tripEnd: trip.endDate
        )
    }
}

public enum GapPersistence {
    public static func upsert(
        payload: GapEditorPayload,
        title: String,
        kind: GapKind,
        price: Double?,
        currency: String?,
        trip: SDTrip,
        bookings: [SDBooking],
        existing: SDGap?,
        context: ModelContext
    ) throws {
        let from = bookings.first(where: { $0.id == payload.fromBookingID })
        let to = bookings.first(where: { $0.id == payload.toBookingID })

        if let existing {
            existing.titleOverride = title
            existing.kindRaw = kind.rawValue
            existing.gapStart = payload.gapStart
            existing.gapEnd = payload.gapEnd
            existing.priceAmount = price
            existing.priceCurrencyCode = currency
            existing.identityKey = payload.key
            existing.trip = trip
            if let from { existing.fromBooking = from }
            if let to { existing.toBooking = to }
        } else {
            let gap = SDGap(
                trip: trip,
                fromBooking: from,
                toBooking: to,
                gapStart: payload.gapStart,
                gapEnd: payload.gapEnd,
                kindRaw: kind.rawValue,
                titleOverride: title,
                identityKey: payload.key,
                priceAmount: price,
                priceCurrencyCode: currency
            )
            context.insert(gap)
        }
        try context.save()
    }
}
