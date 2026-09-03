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

    @Test func menuSingletonInBoundReturnsFullBound() {
        let bound: Set<String> = ["a", "b", "c"]
        let effective = MenuEffectiveSelection.resolve(menu: ["b"], bound: bound)
        #expect(effective == bound)
    }

    @Test func menuSingletonOutsideBoundReturnsSingleton() {
        let bound: Set<String> = ["a", "b"]
        let effective = MenuEffectiveSelection.resolve(menu: ["z"], bound: bound)
        #expect(effective == ["z"])
    }

    @Test func menuMultiSubsetOfBoundReturnsBound() {
        let bound: Set<String> = ["a", "b", "c"]
        let effective = MenuEffectiveSelection.resolve(menu: ["a", "b"], bound: bound)
        #expect(effective == bound)
    }

    @Test func menuMultiNotSubsetReturnsMenu() {
        let bound: Set<String> = ["a", "b"]
        let effective = MenuEffectiveSelection.resolve(menu: ["a", "z"], bound: bound)
        #expect(effective == ["a", "z"])
    }

    @Test func emptyMenuReturnsEmpty() {
        let effective = MenuEffectiveSelection.resolve(menu: Set<String>(), bound: ["a"])
        #expect(effective.isEmpty)
    }
}
