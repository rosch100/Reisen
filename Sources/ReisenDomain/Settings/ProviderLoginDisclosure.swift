import Foundation

public enum ProviderLoginDisclosureKeys {
    public static let accepted = "reisen_providerLoginDisclosureAccepted"
}

public enum ProviderLoginDisclosure {
    public static var title: String {
        localizedTitle()
    }

    public static var message: String {
        localizedMessage()
    }

    public static var acceptButtonTitle: String {
        localizedAcceptButtonTitle()
    }

    public static func localizedTitle(locale: Locale = .current) -> String {
        locale.reisenPrefersGerman ? "Provider-Anmeldung" : "Provider sign-in"
    }

    public static func localizedMessage(locale: Locale = .current) -> String {
        if locale.reisenPrefersGerman {
            return """
            Reisen ist nicht mit Booking.com, Airbnb, Check24, Opodo, GetYourGuide, Traveloka oder anderen Anbietern verbunden oder von diesen unterstützt.

            Du meldest dich mit deinem eigenen Konto auf deren Website an. Die Sitzung bleibt auf diesem Gerät; Reisen synchronisiert nur deine Buchungen für die persönliche Übersicht.
            """
        }
        return """
        Reisen is not affiliated with or endorsed by Booking.com, Airbnb, Check24, Opodo, GetYourGuide, Traveloka, or other providers.

        You sign in with your own account on their website. The session stays on this device; Reisen only syncs your bookings for your personal overview.
        """
    }

    public static func localizedAcceptButtonTitle(locale: Locale = .current) -> String {
        locale.reisenPrefersGerman ? "Verstanden" : "OK"
    }

    public static func isAccepted(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: ProviderLoginDisclosureKeys.accepted)
    }

    public static func accept(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: ProviderLoginDisclosureKeys.accepted)
    }
}
