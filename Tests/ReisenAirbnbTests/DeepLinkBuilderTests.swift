import Testing
import Foundation
import ReisenDomain
@testable import ReisenAirbnb

@Test func airbnbDeepLinkBuilder_homesPrefill() {
    let context = GapContext(
        gapStart: Date(timeIntervalSince1970: 1_800_000_000),
        gapEnd: Date(timeIntervalSince1970: 1_800_086_400),
        kind: .lodging,
        fromLocationFrom: nil,
        fromLocationTo: "Berlin",
        toLocationFrom: nil,
        toLocationTo: nil
    )
    let result = AirbnbDeepLinkBuilder().suggestions(for: context)
    #expect(result.links.count == 1)
    #expect(result.links[0].category == .hotel)
    #expect(result.links[0].url?.absoluteString.contains("/s/Berlin/homes") == true)
    #expect(result.links[0].url?.absoluteString.contains("checkin=") == true)
}
