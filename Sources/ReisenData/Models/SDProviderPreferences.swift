import Foundation
import SwiftData
import ReisenDomain

/// CloudKit-gespiegelte Provider-Prefs (Enablement + setupCompleted). Singleton-Record.
@Model
public final class SDProviderPreferences {
    public var id: UUID = ProviderPreferencesRecordID.singleton
    public var setupCompleted: Bool = false
    /// Kommagetrennte `ProviderID.rawValue` der aktivierten Sync-Portale.
    public var enabledProviderRawCSV: String = ""

    public init(
        id: UUID = ProviderPreferencesRecordID.singleton,
        setupCompleted: Bool = false,
        enabledProviderRawCSV: String = ""
    ) {
        self.id = id
        self.setupCompleted = setupCompleted
        self.enabledProviderRawCSV = enabledProviderRawCSV
    }
}
