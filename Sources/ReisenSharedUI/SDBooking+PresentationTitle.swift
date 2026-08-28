import ReisenData
import ReisenDomain

/// UI-Titel (lokalisiert); Sync/Side-Effects bleiben bei `SDBooking.displayTitle`.
public extension SDBooking {
    var presentationTitle: String {
        title ?? bookingType.displayLabel
    }
}
