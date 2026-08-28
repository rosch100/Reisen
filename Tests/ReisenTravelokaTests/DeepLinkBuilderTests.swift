import Testing
import Foundation
import ReisenDomain
@testable import ReisenTraveloka

@Test func travelokaDeepLinkBuilder_activitiesRequireDestination() {
    let context = GapContext(
        gapStart: Date(timeIntervalSince1970: 1_800_000_000),
        gapEnd: Date(timeIntervalSince1970: 1_800_086_400),
        kind: .lodging,
        fromLocationFrom: nil,
        fromLocationTo: nil,
        toLocationFrom: nil,
        toLocationTo: nil
    )
    let result = TravelokaDeepLinkBuilder().suggestions(for: context)
    #expect(result.links.isEmpty)
    #expect(result.issues == [.missingDestinationHint])
}

@Test func travelokaDeepLinkBuilder_activitiesPrefillWithDestination() {
    let context = GapContext(
        gapStart: Date(timeIntervalSince1970: 1_800_000_000),
        gapEnd: Date(timeIntervalSince1970: 1_800_086_400),
        kind: .lodging,
        fromLocationFrom: nil,
        fromLocationTo: "Bali",
        toLocationFrom: nil,
        toLocationTo: nil
    )
    let result = TravelokaDeepLinkBuilder().suggestions(for: context)
    let activity = result.links.first { $0.category == .activity }
    #expect(activity?.url?.absoluteString.contains("q=Bali") == true)
    #expect(!result.issues.contains(.missingFromIATA))
}
