import Foundation

/// HIG: Während Create ist die Timeline-/Sidebar-Selektion der Create-Draft, nicht die alte Buchung.
public enum BookingCreateDraftSelection {
    public static let timelineID = "reisen.booking.create-draft"

    public static func isCreateDraft(_ timelineID: String?) -> Bool {
        timelineID == Self.timelineID
    }

    public static func selectCreateDraft(into selectedTimelineID: inout String?) {
        selectedTimelineID = timelineID
    }
}
