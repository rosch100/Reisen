import Foundation

/// Outline under „Offene Buchungen“ / „Abgelaufen“-Offen: Section-Header + Blattzeilen.
/// Keine Sammelkategorie-/Aggregat-Elternzeile unter dem Header — Expand steuert nur die Blattliste.
public enum SidebarOpenSectionOutline {
    public static func visibleBookingIDs(from bookingIDs: [UUID], isExpanded: Bool) -> [UUID] {
        isExpanded ? bookingIDs : []
    }
}
