import Foundation
import Testing
import ReisenBookingCom
import ReisenDomain

@Test("BookingComGuestHintParser mappt synthetic Confirmation-Hints")
func bookingComGuestHintParserParsesSynthetic() throws {
    let hints = try parseResearchFixture("bookingcom_confirmation_hints_synthetic.html")
    #expect(!hints.isEmpty)
    #expect(
        hints.contains {
            $0.sourceKey.contains("HotelChainBedLinen") || $0.sourceKey.contains("towels_sheets")
        }
    )
}

@Test("BookingComGuestHintParser mappt DE-Richtlinien ohne FAQ-Haustiere")
func bookingComGuestHintParserParsesDEConfirmationPolicies() throws {
    let hints = try parseResearchFixture("bookingcom_confirmation_policies_de_synthetic.html")
    #expect(hints.contains { $0.sourceKey.contains("arrival:in_advance") })
    #expect(hints.contains { $0.sourceKey.contains("checkin:photo_id") })
    #expect(!hints.contains { $0.sourceKey.contains("pets:") })
}

@Test("BookingComGuestHintParser ignoriert englische Photo-ID-FAQ")
func bookingComGuestHintParserIgnoresEnglishPhotoIdentificationFAQ() {
    let html = """
    <html><body>
    <h3>What photo identification and documents do I need?</h3>
    <p>Please bring a valid photo ID.</p>
    </body></html>
    """
    let hints = BookingComGuestHintParser().parse(from: html)
    #expect(!hints.contains { $0.sourceKey.contains("checkin:") })
}

@Test("BookingComGuestHintParser erkennt Check-in mit Photo-ID und Kreditkarte")
func bookingComGuestHintParserParsesPhotoIdAndCreditCard() {
    let html = """
    <html><body>
    <h2>Important information</h2>
    <p>You must present a photo ID and credit card at check-in.</p>
    </body></html>
    """
    let hints = BookingComGuestHintParser().parse(from: html)
    #expect(hints.contains { $0.sourceKey.contains("checkin:photo_id") })
}

@Test("BookingComGuestHintParser ignoriert englische Haustier-FAQ")
func bookingComGuestHintParserIgnoresEnglishPetsFAQ() {
    let html = """
    <html><body>
    <h3>How do I know if pets are allowed?</h3>
    <p>Pet policies are listed on the property page under House rules.</p>
    </body></html>
    """
    let hints = BookingComGuestHintParser().parse(from: html)
    #expect(!hints.contains { $0.sourceKey.contains("pets:") })
}

@Test("BookingComGuestHintParser erkennt sichtbare Haustier-Untersagung")
func bookingComGuestHintParserParsesVisiblePetsNotAllowed() {
    let html = "<html><body><h2>Hotelrichtlinien</h2><p>Haustiere sind nicht erlaubt.</p></body></html>"
    let hints = BookingComGuestHintParser().parse(from: html)
    #expect(hints.contains { $0.sourceKey.contains("pets:not_allowed") })
}

@Test("BookingComGuestHintParser erkennt sichtbare Haustiere willkommen ohne Script-i18n")
func bookingComGuestHintParserParsesVisiblePetsWelcome() {
    let html = "<html><body><h2>Hotelrichtlinien</h2><p>Haustiere willkommen. Keine zusätzlichen Kosten.</p></body></html>"
    let hints = BookingComGuestHintParser().parse(from: html)
    #expect(hints.contains { $0.sourceKey.contains("pets:allowed") })
}

private func parseResearchFixture(_ name: String) throws -> [BookingGuestHint] {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("docs/fixtures/provider-research")
        .appendingPathComponent(name)
    let html = try String(contentsOf: url, encoding: .utf8)
    return BookingComGuestHintParser().parse(from: html)
}
