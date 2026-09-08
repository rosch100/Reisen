import Foundation

/// Plant gewünschte Auto-Gap-**Buchungen**.
///
/// Produktentscheidung: Buchungslücken sind editierbare ComputedGap/SDGap-Platzhalter
/// („Lücke: Übernachtung“ / „Lücke: Transport“), keine `provider=autoGap`-Hotel-/Transport-Buchungen.
/// Leerer Plan → Reconciler entfernt veraltete Auto-Einträge.
public enum AutoGapPlanner {
    public static func plan(
        tripStart: Date,
        tripEnd: Date,
        bookings: [Booking]
    ) -> [AutoGapDesired] {
        let real = bookings.filter(\.isRealForGapDetect)
        guard !real.isEmpty, tripEnd >= tripStart else { return [] }
        return []
    }
}
