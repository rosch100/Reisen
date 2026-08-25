import Foundation
import Testing
import ReisenProviders

@Test("StayHintHTMLExtractor findet Bettwäsche/Handtücher in Check24-HTML")
func stayHintHTMLExtractorParsesCheck24Synthetic() throws {
    let html = try loadResearchFixture("check24_hotel_detail_hints_synthetic.html")
    let hints = StayHintHTMLExtractor.extract(from: html, providerRaw: "check24")
    #expect(hints.contains { $0.sourceKey.contains("linen") || $0.sourceKey.contains("towels") })
}

@Test("StayHintHTMLExtractor findet Bettwäsche/Handtücher in Opodo-HTML")
func stayHintHTMLExtractorParsesOpodoSynthetic() throws {
    let html = try loadResearchFixture("opodo_trip_detail_hints_synthetic.html")
    let hints = StayHintHTMLExtractor.extract(from: html, providerRaw: "opodo")
    #expect(hints.contains { $0.sourceKey.contains("linen") || $0.sourceKey.contains("towels") })
}

@Test("StayHintHTMLExtractor liefert leer ohne Treffer")
func stayHintHTMLExtractorEmptyWithoutMatch() {
    let hints = StayHintHTMLExtractor.extract(
        from: "<html><body>Nur Check-in ab 15:00</body></html>",
        providerRaw: "check24"
    )
    #expect(hints.isEmpty)
}

private func loadResearchFixture(_ name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("docs/fixtures/provider-research")
        .appendingPathComponent(name)
    return try String(contentsOf: url, encoding: .utf8)
}
