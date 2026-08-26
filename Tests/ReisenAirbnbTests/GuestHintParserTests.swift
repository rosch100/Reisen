import Foundation
import Testing
import ReisenAirbnb

@Test("AirbnbGuestHintParser mappt synthetic Stay-Hints")
func airbnbGuestHintParserParsesSynthetic() throws {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("docs/fixtures/provider-research/airbnb_stay_hints_synthetic.json")
    let text = try String(contentsOf: url, encoding: .utf8)
    let hints = AirbnbGuestHintParser().parse(from: text)
    let keys = Set(hints.map(\.sourceKey))
    #expect(keys.contains("airbnb:amenity:essentials:absent"))
    #expect(
        keys.contains("airbnb:towels:bring_own")
            || keys.contains("airbnb:linens:bring_own")
            || keys.contains("airbnb:house_rules:prep")
    )
}
