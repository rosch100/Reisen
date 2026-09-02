import Foundation
import ReisenDomain

/// HIG: Während Create ist die Timeline-/Sidebar-Selektion der Create-Draft, nicht die alte Buchung.
public enum BookingCreateDraftSelection {
    public static let timelineID = "reisen.booking.create-draft"

    public static func isCreateDraft(_ timelineID: String?) -> Bool {
        timelineID == Self.timelineID
    }

    public static func isCreateDraftSelection(_ selectedTimelineIDs: Set<String>) -> Bool {
        selectedTimelineIDs.count == 1 && selectedTimelineIDs.contains(timelineID)
    }

    public static func selectCreateDraft(into selectedTimelineID: inout String?) {
        selectedTimelineID = timelineID
    }

    public static func selectCreateDraft(into selectedTimelineIDs: inout Set<String>) {
        selectedTimelineIDs = [timelineID]
    }

    /// Listen-/Inspector-Titel: Platzhalter „Neue Buchung“, sobald getippt der Entwurfstitel.
    public static func displayTitle(typedTitle: String?) -> String {
        let trimmed = (typedTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return L10n.string(.editorCreateTitle)
        }
        return trimmed
    }
}
