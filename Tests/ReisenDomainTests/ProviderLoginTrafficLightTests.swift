import Testing
import Foundation
import ReisenDomain

@Test func trafficLight_disabled_isGray() {
    #expect(ProviderLoginTrafficLight.resolve(isEnabled: false, isLoggedIn: true) == .gray)
    #expect(ProviderLoginTrafficLight.resolve(isEnabled: false, isLoggedIn: false) == .gray)
    #expect(ProviderLoginTrafficLight.resolve(isEnabled: false, isLoggedIn: nil) == .gray)
}

@Test func trafficLight_enabledLoggedIn_isGreen() {
    #expect(ProviderLoginTrafficLight.resolve(isEnabled: true, isLoggedIn: true) == .green)
}

@Test func trafficLight_enabledNotLoggedIn_isRed() {
    #expect(ProviderLoginTrafficLight.resolve(isEnabled: true, isLoggedIn: false) == .red)
}

@Test func trafficLight_enabledUnknownSession_isRed() {
    #expect(ProviderLoginTrafficLight.resolve(isEnabled: true, isLoggedIn: nil) == .red)
}

@Test func trafficLight_displayLabels_areStable() {
    L10n.withLocale(Locale(identifier: "de")) {

    #expect(ProviderLoginTrafficLight.green.displayLabel == L10n.string(.loginStatusGreen))
    #expect(ProviderLoginTrafficLight.red.displayLabel == L10n.string(.loginStatusRed))
    #expect(ProviderLoginTrafficLight.gray.displayLabel == L10n.string(.loginStatusGray))
    }
}
