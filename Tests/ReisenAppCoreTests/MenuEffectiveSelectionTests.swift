import Foundation
import Testing
@testable import ReisenAppCore

struct MenuEffectiveSelectionTests {
    @Test func clickedInSelectionKeepsFullSet() {
        let selected: Set<String> = ["a", "b", "c"]
        let effective = MenuEffectiveSelection.resolve(clicked: "b", selected: selected)
        #expect(effective == selected)
    }

    @Test func clickedOutsideSelectionReturnsSingleton() {
        let selected: Set<String> = ["a", "b"]
        let effective = MenuEffectiveSelection.resolve(clicked: "z", selected: selected)
        #expect(effective == ["z"])
    }

    @Test func emptySelectionReturnsSingletonClicked() {
        let effective = MenuEffectiveSelection.resolve(clicked: "a", selected: Set<String>())
        #expect(effective == ["a"])
    }
}
