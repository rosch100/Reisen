import Foundation
import Testing
import ReisenBookingCom

@Test("BookingComGuestHintParser mappt synthetic Confirmation-Hints")
func bookingComGuestHintParserParsesSynthetic() throws {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("docs/fixtures/provider-research/bookingcom_confirmation_hints_synthetic.html")
    let html = try String(contentsOf: url, encoding: .utf8)
    let hints = BookingComGuestHintParser().parse(from: html)
    #expect(!hints.isEmpty)
    #expect(
        hints.contains {
            $0.sourceKey.contains("HotelChainBedLinen") || $0.sourceKey.contains("towels_sheets")
        }
    )
}
