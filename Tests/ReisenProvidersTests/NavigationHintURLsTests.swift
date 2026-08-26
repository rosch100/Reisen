import Testing
import Foundation
@testable import ReisenProviders

@Test("NavigationHintURLs dedupliziert lokale und Hub-URLs")
func navigationHintURLsDeduplicates() {
    let urls = NavigationHintURLs.ordered(
        localURLString: "https://www.traveloka.com/en-en/user/mybooking",
        hubURLString: "https://www.traveloka.com/en-en/user/mybooking"
    )
    #expect(urls.count == 1)
    #expect(urls[0].absoluteString == "https://www.traveloka.com/en-en/user/mybooking")
}

@Test("NavigationHintURLs behält Reihenfolge bei unterschiedlichen URLs")
func navigationHintURLsPreservesOrder() {
    let urls = NavigationHintURLs.ordered(
        localURLString: "https://www.traveloka.com/en-en/",
        hubURLString: "https://www.traveloka.com/en-en/user/signin"
    )
    #expect(urls.count == 2)
    #expect(urls[0].absoluteString == "https://www.traveloka.com/en-en/")
    #expect(urls[1].absoluteString == "https://www.traveloka.com/en-en/user/signin")
}
