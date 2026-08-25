import Foundation
import ReisenDomain

/// Wann Traveloka-Detail-Enrichment nach dem Katalog noch nötig ist.
public enum TravelokaEnrichmentNeeds {
    public static func shouldEnrich(
        _ draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        if requiresDeadlines && draft.deadlines.isEmpty { return true }
        if draft.status == .unknown { return true }
        switch draft.bookingType {
        case .activity:
            return draft.operatorName == nil
                || draft.isAllDay == nil
                || draft.passengers.isEmpty
                || draft.locationToAddress == nil
        case .hotel:
            return draft.hotelCheckInMinutes == nil || draft.hotelCheckOutMinutes == nil
        case .flight:
            return draft.passengers.isEmpty || draft.rateDetails?.airline == nil
        case .ferry:
            return false
        case .other:
            return draft.operatorName == nil && draft.locationFrom == nil
        }
    }
}
