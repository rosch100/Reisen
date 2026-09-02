import Testing
import ReisenAppCore
import ReisenDomain
import ReisenPasteImport

@Test @MainActor
func pasteImportSession_injectsFixtureOnlyForExplicitUITestingLaunch() {
    let session = PasteImportSession()
    session.injectTestingFixture(enabled: false)
    #expect(session.pending.isEmpty)

    session.injectTestingFixture(enabled: true)
    #expect(session.pending.count == 1)
    #expect(session.pending[0].draft.title == "UI Testing Imported Booking")
    #expect(session.pending[0].match == .none)
}

@Test @MainActor
func pasteImportFixture_argumentIsRecognizedOnlyWithUITesting() {
    #expect(UITestingLaunch.shouldInjectPasteImportFixture(arguments: [
        UITestingLaunch.argument,
        UITestingLaunch.pasteImportArgument,
    ]))
    #expect(!UITestingLaunch.shouldInjectPasteImportFixture(arguments: [
        UITestingLaunch.pasteImportArgument,
    ]))
}
