import Foundation
import Testing
import ReisenDomain
import ReisenSharedUI

@Test("TripPeriodExpandPrompt: Hotel-GMT Tag in Range, kein Geräte-TZ-Vortag")
func tripPeriodExpandPrompt_formattedRange_keepsHotelGMTDay() {
    // 2026-09-05 00:00 GMT — Geräte-`.formatted` in westlichen TZs würde oft 4.9. zeigen.
    let stay = HotelStayDate.dateOnly(year: 2026, month: 9, day: 5)
    let end = HotelStayDate.dateOnly(year: 2026, month: 9, day: 10)
    let proposal = TripPeriodExpandOnAssign.Proposal(start: stay, end: end)
    let text = TripPeriodExpandPrompt.formattedRange(proposal: proposal)
    #expect(text.contains("5.9"))
    #expect(text.contains("10.9"))
    #expect(!text.contains("4.9"))
}
