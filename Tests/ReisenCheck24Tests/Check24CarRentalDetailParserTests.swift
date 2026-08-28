import Testing
import Foundation
@testable import ReisenCheck24

@Test("Check24CarRentalDetailParser: CpInitial → Operator, Orte, Preis, Fahrzeug")
func check24CarRentalDetailParserMapsCpInitialFixture() throws {
    let html = try fixtureHTML("check24_rentalcar_detail_redacted.html")
    let parsed = try #require(Check24CarRentalDetailParser.parse(from: html))

    #expect(parsed.title == "Toyota Aygo oder ähnlich")
    #expect(parsed.operatorName == "Car Alliance")
    #expect(parsed.confirmationCode == "REDACTED_BOOKING_NUMBER")
    #expect(parsed.locationFrom == "Madeira Flughafen")
    #expect(parsed.locationTo == "Madeira Flughafen")
    #expect(parsed.locationFromAddress == "Madeira Airport, 9100-105 Madeira")
    #expect(parsed.locationToAddress == "Madeira Airport, 9100-105 Madeira")
    #expect(parsed.vehicleCategory == "Mini-Klasse")
    #expect(parsed.totalPriceCurrency == "EUR")
    #expect(abs((parsed.totalPriceAmount ?? 0) - 202.59) < 0.001)
}

@Test("Check24CarRentalDetailParser: ohne CpInitial → nil")
func check24CarRentalDetailParserMissingCpInitialReturnsNil() {
    #expect(Check24CarRentalDetailParser.parse(from: "<html><body>kein portal</body></html>") == nil)
}

private func fixtureHTML(_ name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("docs/fixtures/provider-research/\(name)")
    return try String(contentsOf: url, encoding: .utf8)
}
