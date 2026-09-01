import Testing
import ReisenDomain
import ReisenSharedUI

@Test func bookingOverlapCaption_isVisible_falseWhenNoPartners() {
    #expect(BookingOverlapCaption.isVisible(partnerTitles: []) == false)
}

@Test func bookingOverlapCaption_isVisible_trueWhenPartnersPresent() {
    #expect(BookingOverlapCaption.isVisible(partnerTitles: ["Hotel A"]) == true)
    #expect(BookingOverlapCaption.isVisible(partnerTitles: ["A", "B"]) == true)
}

@Test func bookingOverlapCaption_labelText_matchesL10nOverlapLabel() {
    let one = ["Hotel A"]
    let many = ["Hotel A", "Flug B", "Tour C"]
    #expect(BookingOverlapCaption.labelText(partnerTitles: one) == L10n.overlapLabel(partnerTitles: one))
    #expect(BookingOverlapCaption.labelText(partnerTitles: many) == L10n.overlapLabel(partnerTitles: many))
}

@Test func bookingOverlapCaption_labelText_hasNoPlusCountBadge() {
    let text = BookingOverlapCaption.labelText(partnerTitles: ["Hotel A"])
    #expect(!text.contains("+"))
    #expect(text.contains("Hotel A"))
}
