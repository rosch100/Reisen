import Foundation
import ReisenDomain

/// Bekannte native iOS-Apps für Sync-Provider (URL-Schemes + Erkennung).
///
/// Erkennung ist best-effort: `canOpenURL` liefert nur, ob *irgendeine* App das Schema
/// registriert hat. Undokumentierte oder falsche Schemata → kein Treffer, kein Auto-Enable.
public enum ProviderNativeApp: Sendable {
    /// Custom-URL-Schemata pro Provider (best-effort; fehlende/ungültige Einträge = nicht erkannt).
    private static let urlSchemesByProvider: [ProviderID: [String]] = [
        .booking: ["booking"],
        .airbnb: ["airbnb"],
        .check24: ["check24"],
        .getYourGuide: ["getyourguide", "gyg"],
        .traveloka: ["traveloka"],
        .opodo: ["opodo"],
    ]

    /// Alle Schemata für `LSApplicationQueriesSchemes` / `canOpenURL` (SSOT, alphabetisch).
    public static let queryURLSchemes: [String] = {
        let schemes = ProviderID.syncProviderIDs.compactMap { urlSchemes(for: $0) }.flatMap { $0 }
        return Array(Set(schemes)).sorted()
    }()

    /// Custom-URL-Schemata pro Provider (best-effort; fehlende Treffer = nicht erkannt).
    public static func urlSchemes(for providerID: ProviderID) -> [String]? {
        urlSchemesByProvider[providerID]
    }

    public static func externalOpenTitle(for providerID: ProviderID, isNativeAppInstalled: Bool) -> String {
        if isNativeAppInstalled {
            return "In \(providerID.displayName)-App öffnen"
        }
        return "Buchung öffnen"
    }
}
