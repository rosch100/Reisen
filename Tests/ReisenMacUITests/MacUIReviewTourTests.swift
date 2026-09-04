import XCTest
import ReisenSharedUI

@MainActor
final class MacUIReviewTourTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testReviewTourWritesManifestAndDumps() throws {
        let directory = try ReviewArtifactWriter.makeDirectory()
        let tripReview = MacUI.launchPopulated()
        tripReview.waitForWindow()
        tripReview.waitFor(UITestingIdentifiers.sidebar)

        tripReview.waitFor(UITestingIdentifiers.seededTripRow).click()
        tripReview.waitFor(UITestingIdentifiers.detail)
        if tripReview.element(UITestingIdentifiers.addBooking).waitForExistence(timeout: 3) {
            tripReview.element(UITestingIdentifiers.addBooking).click()
            _ = tripReview.element(UITestingIdentifiers.bookingEditor).waitForExistence(timeout: 4)
            tripReview.app.typeKey(.escape, modifierFlags: [])
        }

        tripReview.waitFor(UITestingIdentifiers.seededTripRow).rightClick()
        if tripReview.app.menuItems[UITestingIdentifiers.deleteTripMenu].waitForExistence(timeout: 3) {
            tripReview.app.menuItems[UITestingIdentifiers.deleteTripMenu].click()
            _ = tripReview.app.dialogs.firstMatch.waitForExistence(timeout: 3)
                || tripReview.app.sheets.firstMatch.waitForExistence(timeout: 1)
            tripReview.app.typeKey(.escape, modifierFlags: [])
        }

        try ReviewArtifactWriter.write(
            app: tripReview.app,
            directory: directory,
            screen: "populated",
            testCase: self
        )

        tripReview.app.terminate()

        let chromeReview = MacUI.launchPopulated()
        chromeReview.waitForWindow()
        chromeReview.waitFor(UITestingIdentifiers.sidebar)
        chromeReview.app.typeKey(",", modifierFlags: .command)
        _ = chromeReview.element(UITestingIdentifiers.settings).waitForExistence(timeout: 4)
        chromeReview.app.typeKey("w", modifierFlags: .command)
        if chromeReview.element(UITestingIdentifiers.providerRow("check24")).waitForExistence(timeout: 2) {
            chromeReview.element(UITestingIdentifiers.providerRow("check24")).click()
            _ = chromeReview.element(UITestingIdentifiers.syncChrome).waitForExistence(timeout: 4)
        }
        try ReviewArtifactWriter.write(
            app: chromeReview.app,
            directory: directory,
            screen: "chrome",
            testCase: self
        )
        chromeReview.app.terminate()

        let empty = MacUI.launchEmpty()
        empty.waitForWindow()
        empty.dismissProviderSetupIfPresent()
        empty.waitFor(UITestingIdentifiers.emptyState)
        try ReviewArtifactWriter.write(
            app: empty.app,
            directory: directory,
            screen: "empty",
            testCase: self
        )
        try ReviewArtifactWriter.writeManifest(directory: directory, testCase: self)
    }
}
