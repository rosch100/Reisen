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
    case multipleBookingsOnly
    case mixedOrGapsOnly
}

public enum TripTimelineContextActions {
    public static func kind(
        selectedIDs: Set<String>,
        isBookingID: (String) -> Bool,
        isGapID: (String) -> Bool
    ) -> TripTimelineSelectionKind {
        guard !selectedIDs.isEmpty else { return .empty }
        let bookings = selectedIDs.filter(isBookingID)
        let gaps = selectedIDs.filter(isGapID)
        if selectedIDs.count == 1 {
            if bookings.count == 1 { return .singleBooking }
            if gaps.count == 1 { return .singleGap }
            return .mixedOrGapsOnly
        }
        if bookings.count == selectedIDs.count {
            return .multipleBookingsOnly
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
        case .multipleBookingsOnly:
            return [.batchRemoveFromTrip, .batchDeleteBooking]
        }
    }
}
