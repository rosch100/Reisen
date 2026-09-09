import Testing
import ReisenSharedUI

@Test func copyableLabeledValueAppearance_listSeparatesLabelFromValue() {
    let appearance = CopyableLabeledValueAppearance.forStyle(.list)
    #expect(appearance.labelUsesSecondaryForeground)
    #expect(appearance.labelTextStyle != appearance.defaultValueTextStyle)
    #expect(appearance.defaultValueTextStyle == .body)
}

@Test func copyableLabeledValueAppearance_inspectorKeepsCaptionHierarchy() {
    let appearance = CopyableLabeledValueAppearance.forStyle(.inspector)
    #expect(appearance.labelUsesSecondaryForeground)
    #expect(appearance.labelTextStyle == .caption2)
    #expect(appearance.defaultValueTextStyle == .caption)
}
