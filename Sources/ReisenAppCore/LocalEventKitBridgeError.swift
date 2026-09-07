import Foundation
import ReisenDomain

/// EventKit-Fehler der Bridge — `Sendable`/`nonisolated`, nutzbar vom Deadline-Writer-Actor.
public enum LocalEventKitBridgeError: LocalizedError, PrivacyAccessDenying, Sendable {
    case accessDenied
    case calendarNotFound
    case calendarModificationDenied
    case calendarWriteFailed
    case reminderAccessDenied
    case reminderWriteFailed
    case reminderCalendarNotFound

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return PrivacySettingPane.calendars.denialMessage
        case .calendarNotFound:
            return "Kein Kalender mit dem angegebenen Titel gefunden."
        case .calendarModificationDenied:
            return """
            Der Kalender kann nicht geändert werden.

            Hintergrund: Einige Kalender-Accounts (z. B. Exchange/Google) erlauben eventuell kein Hinzufügen/Entfernen von Kalenderobjekten.

            Bitte prüfe in der Kalender-App bzw. bei deinem Account, ob Reisen das Hinzufügen/Entfernen von Kalendereinträgen darf.
            """
        case .calendarWriteFailed:
            return "Kalender-Synchronisation fehlgeschlagen (Schreiben nicht möglich)."
        case .reminderAccessDenied:
            return PrivacySettingPane.reminders.denialMessage
        case .reminderCalendarNotFound:
            return "Kein Kalender für Erinnerungen gefunden."
        case .reminderWriteFailed:
            return "Erinnerungen-Synchronisation fehlgeschlagen (Schreiben nicht möglich)."
        }
    }

    public var privacySettingPane: PrivacySettingPane? {
        switch self {
        case .accessDenied: return .calendars
        case .reminderAccessDenied: return .reminders
        case .calendarNotFound, .calendarModificationDenied, .calendarWriteFailed,
             .reminderCalendarNotFound, .reminderWriteFailed:
            return nil
        }
    }
}

extension LocalEventKitBridge {
    public typealias EventKitError = LocalEventKitBridgeError
}
