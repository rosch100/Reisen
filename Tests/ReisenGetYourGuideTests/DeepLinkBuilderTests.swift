import Testing
import Foundation
import ReisenDomain
@testable import ReisenGetYourGuide

@Test func getYourGuideDeepLinkBuilder_activityPrefill() {
    let context = GapContext(
        gapStart: Date(timeIntervalSince1970: 1_800_000_000),
        gapEnd: Date(timeIntervalSince1970: 1_800_086_400),
        kind: .lodging,
        fromLocationFrom: nil,
        fromLocationTo: "Yogyakarta",
        toLocationFrom: nil,
        toLocationTo: nil
    )
    let result = GetYourGuideDeepLinkBuilder().suggestions(for: context)
    #expect(result.links.count == 1)
    #expect(result.links[0].category == .activity)
    #expect(result.links[0].url?.absoluteString.contains("q=Yogyakarta") == true)
}
