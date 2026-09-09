import Foundation
import ReisenDomain

/// Entscheidungsplan für manuelle Buchungsanlage in einer Reise (macOS/iOS-Parität).
public enum TripCreateBookingAssignmentPlan: Equatable, Sendable {
    case assignToTrip
    case askExpand(TripPeriodExpandOnAssign.Proposal)
}

public enum TripCreateBookingAssignment {
    /// Wie macOS `TripDetailView.saveEditor` vor `createBookingAssigned`.
    public static func plan(
        bookingType: BookingType,
        draftStartAt: Date,
        draftEndAt: Date,
        tripStart: Date,
        tripEnd: Date
    ) -> TripCreateBookingAssignmentPlan {
        let bookingStart: Date
        let bookingEnd: Date
        if bookingType == .hotel {
            bookingStart = HotelStayDate.dateOnly(fromLocalPickerDate: draftStartAt)
            bookingEnd = HotelStayDate.dateOnly(fromLocalPickerDate: draftEndAt)
        } else {
            bookingStart = draftStartAt
            bookingEnd = draftEndAt
        }
        if let proposal = TripPeriodExpandOnAssign.proposalIfNeeded(
            bookingStart: bookingStart,
            bookingEnd: bookingEnd,
            tripStart: tripStart,
            tripEnd: tripEnd
        ) {
            return .askExpand(proposal)
        }
        return .assignToTrip
    }
}
