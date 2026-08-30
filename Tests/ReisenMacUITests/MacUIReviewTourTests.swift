import XCTest
import ReisenSharedUI

@MainActor
final class MacUIReviewTourTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func setUpWithError() throws {
        let enabled = ProcessInfo.processInfo.environment["REISEN_UI_REVIEW"] == "1"
        try XCTSkipUnless(enabled, "On-demand Review-Tour; startet nur mit REISEN_UI_REVIEW=1")
    }

    func testReviewTourWritesManifestAndDumps() throws {
        let directory = try ReviewArtifactWriter.makeDirectory()
        let populated = MacUI.launchPopulated()
        populated.waitForWindow()
        populated.waitFor(UITestingIdentifiers.sidebar)

        populated.app.typeKey(",", modifierFlags: .command)
        _ = populated.element(UITestingIdentifiers.settings).waitForExistence(timeout: 4)
        populated.app.typeKey("w", modifierFlags: .command)

        if populated.element(UITestingIdentifiers.providerRow("check24")).waitForExistence(timeout: 2) {
            populated.element(UITestingIdentifiers.providerRow("check24")).click()
            _ = populated.element(UITestingIdentifiers.syncChrome).waitForExistence(timeout: 4)
        }

        populated.waitFor(UITestingIdentifiers.seededTripRow).click()
        populated.waitFor(UITestingIdentifiers.detail)
        if populated.element(UITestingIdentifiers.addBooking).waitForExistence(timeout: 3) {
            populated.element(UITestingIdentifiers.addBooking).click()
            _ = populated.element(UITestingIdentifiers.bookingEditor).waitForExistence(timeout: 4)
            populated.app.typeKey(.escape, modifierFlags: [])
        }

        populated.waitFor(UITestingIdentifiers.seededTripRow).rightClick()
        if populated.app.menuItems[UITestingIdentifiers.deleteTripMenu].waitForExistence(timeout: 3) {
            populated.app.menuItems[UITestingIdentifiers.deleteTripMenu].click()
            _ = populated.app.dialogs.firstMatch.waitForExistence(timeout: 3)
                || populated.app.sheets.firstMatch.waitForExistence(timeout: 1)
            populated.app.typeKey(.escape, modifierFlags: [])
        }

        try ReviewArtifactWriter.write(
            app: populated.app,
            directory: directory,
            screen: "populated"
        )

        populated.app.terminate()

        let empty = MacUI.launchEmpty()
        empty.waitForWindow()
        empty.waitFor(UITestingIdentifiers.emptyState)
        try ReviewArtifactWriter.write(
            app: empty.app,
            directory: directory,
            screen: "empty"
        )
        try ReviewArtifactWriter.writeManifest(directory: directory)
    }
}
