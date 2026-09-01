import Testing
import ReisenDomain
import ReisenSharedUI

@Test func bookingOverlapCaption_isVisible_falseWhenCountZero() {
    #expect(BookingOverlapCaption.isVisible(overlapCount: 0) == false)
}

@Test func bookingOverlapCaption_isVisible_trueWhenCountAtLeastOne() {
    #expect(BookingOverlapCaption.isVisible(overlapCount: 1) == true)
    #expect(BookingOverlapCaption.isVisible(overlapCount: 3) == true)
}

@Test func bookingOverlapCaption_labelText_matchesL10nOverlapLabel() {
    #expect(BookingOverlapCaption.labelText(extraCount: 0) == L10n.overlapLabel(extraCount: 0))
    #expect(BookingOverlapCaption.labelText(extraCount: 1) == L10n.overlapLabel(extraCount: 1))
    #expect(BookingOverlapCaption.labelText(extraCount: 2) == L10n.overlapLabel(extraCount: 2))
}

@Test func bookingOverlapCaption_accessibilityMatchesLabelText() {
    for n in [0, 1, 4] {
        let text = BookingOverlapCaption.labelText(extraCount: n)
        #expect(text == L10n.overlapLabel(extraCount: n))
    }
}
