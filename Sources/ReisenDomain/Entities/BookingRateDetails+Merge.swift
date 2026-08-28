import Foundation

extension BookingRateDetails {
    public static func merging(existing: Self?, incoming: Self?) -> Self? {
        guard let incoming else { return existing }
        guard var merged = existing else { return incoming }

        assignNonEmpty(incoming.rawDetailsFingerprint, into: &merged, \.rawDetailsFingerprint)
        assignOptional(incoming.totalPriceAmount, into: &merged, \.totalPriceAmount)
        assignOptional(incoming.totalPriceCurrency, into: &merged, \.totalPriceCurrency)
        assignOptional(incoming.roomCategory, into: &merged, \.roomCategory)
        if incoming.boardType != .unknown {
            merged.boardType = incoming.boardType
        }
        assignOptional(incoming.includedBreakfast, into: &merged, \.includedBreakfast)
        assignOptional(incoming.guestCount, into: &merged, \.guestCount)
        assignOptional(incoming.roomCount, into: &merged, \.roomCount)
        assignOptional(incoming.airline, into: &merged, \.airline)
        assignOptional(incoming.passengerCount, into: &merged, \.passengerCount)
        assignOptional(incoming.baggageInfoRaw, into: &merged, \.baggageInfoRaw)
        assignOptional(incoming.lastParsedAt, into: &merged, \.lastParsedAt)
        if !incoming.roomItems.isEmpty {
            merged.roomItems = incoming.roomItems
        }
        return merged
    }

    private static func assignOptional<T>(
        _ incoming: T?,
        into target: inout Self,
        _ keyPath: WritableKeyPath<Self, T?>
    ) {
        guard let incoming else { return }
        target[keyPath: keyPath] = incoming
    }

    private static func assignNonEmpty(
        _ incoming: String?,
        into target: inout Self,
        _ keyPath: WritableKeyPath<Self, String?>
    ) {
        guard let incoming = NonEmpty.string(incoming) else { return }
        target[keyPath: keyPath] = incoming
    }
}
