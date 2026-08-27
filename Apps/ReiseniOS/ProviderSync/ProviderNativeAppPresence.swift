import UIKit

import ReisenDomain
import ReisenProviders

enum ProviderNativeAppPresence {
    static func isInstalled(_ providerID: ProviderID) -> Bool {
        guard let schemes = ProviderNativeApp.urlSchemes(for: providerID) else { return false }
        return schemes.contains { scheme in
            guard let url = URL(string: "\(scheme)://") else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
    }

    static func installedProviderIDs() -> [ProviderID] {
        ProviderID.syncProviderIDs.filter(isInstalled)
    }

    @discardableResult
    static func applyAutoEnableIfNeeded(defaults: UserDefaults = .standard) -> Bool {
        ProviderAppAutoEnable.applyIfNeeded(
            installedProviderIDs: installedProviderIDs(),
            defaults: defaults
        )
    }
}
