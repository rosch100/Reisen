import ReisenData
import ReisenDomain

/// UI-Titel (lokalisiert); Sync/Side-Effects bleiben bei `SDBooking.displayTitle`.
public extension SDBooking {
    var presentationTitle: String {
        let base = title ?? bookingType.displayLabel
        guard providerRaw == ProviderID.autoGap.rawValue else { return base }
        return "\(base) · \(L10n.string(.bookingBadgeAutoGap))"
    }
}
