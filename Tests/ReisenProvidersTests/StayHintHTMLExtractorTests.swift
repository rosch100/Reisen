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

@Test("StayHintHTMLExtractor erzeugt keine House-Rules auf Check24-HTML")
func stayHintHTMLExtractorIgnoresCheck24HouseRulePhrases() {
    let html = """
    <html><body>
    <p>Beim Check-in Lichtbildausweis vorlegen.</p>
    <p>Bitte Ankunftszeit im Voraus mitteilen.</p>
    <p>Haustiere willkommen.</p>
    </body></html>
    """
    let hints = StayHintHTMLExtractor.extract(from: html, providerRaw: "check24")
    #expect(!hints.contains { $0.sourceKey.contains("checkin:") })
    #expect(!hints.contains { $0.sourceKey.contains("arrival:") })
    #expect(!hints.contains { $0.sourceKey.contains("pets:") })
}

@Test("StayHintHTMLExtractor lässt Booking-House-Rules dem Booking-Parser")
func stayHintHTMLExtractorOmitsHouseRulesOnDEConfirmation() throws {
    let html = try loadResearchFixture("bookingcom_confirmation_policies_de_synthetic.html")
    let hints = StayHintHTMLExtractor.extract(from: html, providerRaw: "booking")
    #expect(!hints.contains { $0.sourceKey.contains("arrival:") })
    #expect(!hints.contains { $0.sourceKey.contains("checkin:") })
    #expect(!hints.contains { $0.sourceKey.contains("pets:") })
}

@Test("StayHintHTMLExtractor nutzt DE-Marker Wichtige Information für Linen-Hinweise")
func stayHintHTMLExtractorParsesSingularWichtigeInformation() {
    let html = """
    <html><body>
    <h2>Wichtige Information</h2>
    <p>Bettwäsche wird nicht gestellt.</p>
    </body></html>
    """
    let hints = StayHintHTMLExtractor.extract(from: html, providerRaw: "booking")
    #expect(hints.contains { $0.sourceKey.contains("linen:not_provided") })
    #expect(hints.contains { $0.sourceKey.contains("important_notice") })
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
