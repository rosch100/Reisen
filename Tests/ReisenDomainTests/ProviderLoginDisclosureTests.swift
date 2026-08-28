import Foundation
import Testing
import ReisenDomain

@Test func providerLoginDisclosure_startsUnaccepted() {
    let suite = "ReisenTests.providerLoginDisclosure"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    #expect(!ProviderLoginDisclosure.isAccepted(defaults: defaults))
    ProviderLoginDisclosure.accept(defaults: defaults)
    #expect(ProviderLoginDisclosure.isAccepted(defaults: defaults))
}

@Test func providerLoginDisclosure_englishCopy() {
    let locale = Locale(identifier: "en_US")
    #expect(ProviderLoginDisclosure.localizedTitle(locale: locale) == "Provider sign-in")
    #expect(ProviderLoginDisclosure.localizedAcceptButtonTitle(locale: locale) == "OK")
    let message = ProviderLoginDisclosure.localizedMessage(locale: locale)
    #expect(message.contains("not affiliated"))
    #expect(message.contains("billiger-mietwagen.de"))
}

@Test func providerLoginDisclosure_germanCopy() {
    let locale = Locale(identifier: "de_DE")
    #expect(ProviderLoginDisclosure.localizedTitle(locale: locale) == "Provider-Anmeldung")
    #expect(ProviderLoginDisclosure.localizedAcceptButtonTitle(locale: locale) == "Verstanden")
    let message = ProviderLoginDisclosure.localizedMessage(locale: locale)
    #expect(message.contains("nicht mit"))
    #expect(message.contains("billiger-mietwagen.de"))
}
