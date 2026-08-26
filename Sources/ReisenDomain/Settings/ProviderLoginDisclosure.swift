import Foundation

public enum ProviderLoginDisclosureKeys {
    public static let accepted = "reisen_providerLoginDisclosureAccepted"
}

public enum ProviderLoginDisclosure {
    public static let title = "Provider-Anmeldung"

    public static let message = """
    Reisen ist nicht mit Booking.com, Airbnb, Check24, Opodo, GetYourGuide, Traveloka oder anderen Anbietern verbunden oder von diesen unterstützt.

    Du meldest dich mit deinem eigenen Konto auf deren Website an. Die Sitzung bleibt auf diesem Gerät; Reisen synchronisiert nur deine Buchungen für die persönliche Übersicht.
    """

    public static func isAccepted(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: ProviderLoginDisclosureKeys.accepted)
    }

    public static func accept(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: ProviderLoginDisclosureKeys.accepted)
    }
}
