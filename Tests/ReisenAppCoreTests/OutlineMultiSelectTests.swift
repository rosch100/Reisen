import Foundation
import Testing
@testable import ReisenAppCore

struct OutlineMultiSelectTests {
    private let ordered = ["a", "b", "c", "d"]

    @Test func replaceSelectsOnlyClickedAndSetsAnchor() {
        let result = OutlineMultiSelect.apply(
            clicked: "c",
            current: ["a", "b"],
            orderedVisible: ordered,
            anchor: "a",
            click: .replace
        )
        #expect(result.selected == ["c"])
        #expect(result.newAnchor == "c")
    }

    @Test func toggleAddsClickedWhenAbsent() {
        let result = OutlineMultiSelect.apply(
            clicked: "c",
            current: ["a"],
            orderedVisible: ordered,
            anchor: "a",
            click: .toggle
        )
        #expect(result.selected == ["a", "c"])
        #expect(result.newAnchor == "a")
    }

    @Test func toggleRemovesClickedWhenPresentKeepingAnchor() {
        let result = OutlineMultiSelect.apply(
            clicked: "c",
            current: ["a", "c"],
            orderedVisible: ordered,
            anchor: "a",
            click: .toggle
        )
        #expect(result.selected == ["a"])
        #expect(result.newAnchor == "a")
    }

    @Test func toggleRemovingAnchorMovesAnchorToClickedIfStillSelected() {
        let result = OutlineMultiSelect.apply(
            clicked: "a",
            current: ["a", "c"],
            orderedVisible: ordered,
            anchor: "a",
            click: .toggle
        )
        #expect(result.selected == ["c"])
        #expect(result.newAnchor == "c")
    }

    @Test func toggleEmptyResultFallsBackToClicked() {
        let result = OutlineMultiSelect.apply(
            clicked: "a",
            current: ["a"],
            orderedVisible: ordered,
            anchor: "a",
            click: .toggle
        )
        #expect(result.selected == ["a"])
        #expect(result.newAnchor == "a")
    }

    @Test func extendRangeFromAnchorToClicked() {
        let result = OutlineMultiSelect.apply(
            clicked: "d",
            current: ["a"],
            orderedVisible: ordered,
            anchor: "b",
            click: .extendRange
        )
        #expect(result.selected == ["b", "c", "d"])
        #expect(result.newAnchor == "b")
    }

    @Test func extendRangeWithMissingAnchorFallsBackToClicked() {
        let result = OutlineMultiSelect.apply(
            clicked: "c",
            current: ["a"],
            orderedVisible: ordered,
            anchor: "z",
            click: .extendRange
        )
        #expect(result.selected == ["c"])
        #expect(result.newAnchor == "c")
    }

    @Test func extendRangeWithEmptyOrderedFallsBackToClicked() {
        let result = OutlineMultiSelect.apply(
            clicked: "c",
            current: ["a"],
            orderedVisible: [],
            anchor: "a",
            click: .extendRange
        )
        #expect(result.selected == ["c"])
        #expect(result.newAnchor == "c")
    }
}
