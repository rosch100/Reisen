import Foundation

/// Kontextaktionen der Trip-Timeline (SSOT für Selection-Menü und Tests).
public enum TripTimelineContextAction: String, Equatable, Sendable, CaseIterable {
    case edit
    case addBooking
    case editGap
    case deleteBooking
    case removeFromTrip
    case batchRemoveFromTrip
    case batchDeleteBooking
    case copy
    case openPortal
}

public enum TripTimelineSelectionKind: Equatable, Sendable {
    case empty
    case singleBooking
    case singleGap
    case multipleBookings
    case mixedOrGapsOnly
}

public enum TripTimelineContextActions {
    /// Booking-IDs in der Selektion (Gaps und sonstige Tags ausgefiltert).
    public static func bookingIDs(
        in selectedIDs: Set<String>,
        isBookingID: (String) -> Bool
    ) -> Set<String> {
        Set(selectedIDs.filter(isBookingID))
    }

    public static func kind(
        selectedIDs: Set<String>,
        isBookingID: (String) -> Bool,
        isGapID: (String) -> Bool
    ) -> TripTimelineSelectionKind {
        guard !selectedIDs.isEmpty else { return .empty }
        let bookings = bookingIDs(in: selectedIDs, isBookingID: isBookingID)
        let gaps = selectedIDs.filter(isGapID)
        // Native List-⇧-Range schließt Zwischen-Gaps mit; Batch gilt für ≥2 Bookings.
        if bookings.count >= 2 {
            return .multipleBookings
        }
        if selectedIDs.count == 1 {
            if bookings.count == 1 { return .singleBooking }
            if gaps.count == 1 { return .singleGap }
            return .mixedOrGapsOnly
        }
        return .mixedOrGapsOnly
    }

    public static func actions(for kind: TripTimelineSelectionKind) -> Set<TripTimelineContextAction> {
        switch kind {
        case .empty, .mixedOrGapsOnly:
            return []
        case .singleBooking:
            return [.edit, .addBooking, .copy, .openPortal, .removeFromTrip, .deleteBooking]
        case .singleGap:
            return [.editGap, .addBooking]
        case .multipleBookings:
            return [.batchRemoveFromTrip, .batchDeleteBooking]
        }
    }
}
