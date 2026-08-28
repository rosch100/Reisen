import Foundation

/// Wann Detail-Enrichment nach dem Katalog noch nötig ist (SSOT, vormals Traveloka-lokal).
public enum DraftEnrichmentNeeds {
    public static func shouldEnrich(
        _ draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        if requiresDeadlines && !draft.deadlines.contains(where: { !$0.isFreeCancellation }) {
            return true
        }
        if draft.bookingType == .hotel && draft.deadlines.isEmpty {
            return true
        }
        if draft.status == .unknown { return true }
        switch draft.bookingType {
        case .activity:
            return draft.operatorName == nil
                || draft.isAllDay == nil
                || draft.passengers.isEmpty
                || draft.locationToAddress == nil
        case .hotel:
            return draft.title == nil
                || draft.hotelCheckInMinutes == nil
                || draft.hotelCheckOutMinutes == nil
                || draft.locationToAddress == nil
                || draft.rateDetails?.roomCategory == nil
        case .flight:
            return draft.passengers.isEmpty || draft.rateDetails?.airline == nil
        case .ferry:
            return draft.title == nil
                || (draft.locationFrom == nil && draft.locationTo == nil)
                || (draft.locationFrom != nil && draft.locationTo != nil && draft.operatorName == nil)
        case .carRental:
            return draft.operatorName == nil
                || draft.locationFrom == nil
                || draft.locationTo == nil
                || draft.locationFromAddress == nil
                || draft.locationToAddress == nil
        case .other:
            return draft.operatorName == nil || draft.locationFrom == nil
        }
    }
}
