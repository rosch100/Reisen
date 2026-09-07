import Foundation
import Testing
import ReisenAppCore

@Suite("CompactListNavigation")
struct CompactListNavigationTests {
    @Test("Compact list must not bind List(selection:) — Selection alone does not push")
    func compactListOmitsSelectionBinding() {
        #expect(CompactListNavigation.listUsesSelectionBinding(usesSplit: false) == false)
        #expect(CompactListNavigation.listUsesSelectionBinding(usesSplit: true) == true)
    }

    @Test("Compact user select sets selection and compactPush for path append")
    func compactUserSelectSetsSelectionAndPush() {
        var selection: UUID?
        var compactPush: UUID?
        let id = UUID()
        CompactListNavigation.applyUserSelect(id: id, selection: &selection, compactPush: &compactPush)
        #expect(selection == id)
        #expect(compactPush == id)
    }
}
