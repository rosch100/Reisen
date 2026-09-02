import Foundation

/// Kontextmenü-Aktionen für Sidebar-/Listen-Einträge (SSOT für Parity-Tests und UI-Verdrahtung).
public enum SidebarContextAction: String, Equatable, Sendable, CaseIterable {
    case edit
    case addBooking
    case deleteTrip
    case deleteBooking
    case removeFromTrip
    case createTripFromAllOpen
    case createTripFromSelection
    case assignToTrip
}

/// Art des Sidebar-/Listen-Eintrags, für den sinnvolle Kontextaktionen definiert sind.
public enum SidebarEntryKind: String, Equatable, Sendable, CaseIterable {
    case trip
    case elapsedTrip
    case tripBooking
    case openBookingMailbox
    case elapsedOpenBookingMailbox
    case openBooking
    case elapsedOpenBooking
}

/// Welche Kontextaktionen ein Eintrag mindestens anbieten muss.
public enum SidebarEntryContextActions {
    public static func actions(for kind: SidebarEntryKind) -> Set<SidebarContextAction> {
        switch kind {
        case .trip, .elapsedTrip:
            return [.edit, .addBooking, .deleteTrip]
        case .tripBooking:
            return [.edit, .addBooking, .deleteBooking, .removeFromTrip]
        case .openBookingMailbox, .elapsedOpenBookingMailbox:
            return [.createTripFromAllOpen]
        case .openBooking, .elapsedOpenBooking:
            return [.deleteBooking, .createTripFromSelection, .assignToTrip]
        }
    }

    /// Selection-Menü abhängig von der Anzahl selektierter gleichartiger Einträge.
    public static func actions(for kind: SidebarEntryKind, selectionCount: Int) -> Set<SidebarContextAction> {
        guard selectionCount > 1 else {
            return actions(for: kind)
        }
        switch kind {
        case .openBooking, .elapsedOpenBooking:
            return [.createTripFromSelection, .deleteBooking]
        case .trip, .elapsedTrip:
            return [.deleteTrip]
        case .tripBooking:
            return [.deleteBooking, .removeFromTrip]
        case .openBookingMailbox, .elapsedOpenBookingMailbox:
            return actions(for: kind)
        }
    }

    public static func includes(_ action: SidebarContextAction, for kind: SidebarEntryKind) -> Bool {
        actions(for: kind).contains(action)
    }
}
