import Foundation

public enum SyncBookingDraftDeadlines {
    public static func apply(
        from draft: ProviderBookingDraft,
        onto booking: inout Booking
    ) -> Int {
        var deadlinesAdded = 0
        if !draft.deadlines.isEmpty {
            booking.cancellationDeadlines = draft.deadlines.map { deadline in
                var d = deadline
                d.bookingID = booking.id
                return d
            }
            deadlinesAdded = draft.deadlines.count
        }

        if let rateDetails = draft.rateDetails {
            var details = rateDetails
            details.bookingID = booking.id
            booking.rateDetails = details
        }
        return deadlinesAdded
    }
}
