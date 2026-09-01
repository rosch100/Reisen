import XCTest
import ReisenSharedUI

@MainActor
final class MacUISmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLaunchShowsSidebar() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.sidebar)
    }

    func testSeededTripShowsDetail() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.seededTripRow).click()
        ui.waitFor(UITestingIdentifiers.detail)
    }

    func testBookingRowOpensInspector() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.seededTripRow).click()
        ui.waitFor(UITestingIdentifiers.detail)
        ui.waitFor(UITestingIdentifiers.seededBookingRow).click()
        ui.waitFor(UITestingIdentifiers.inspector)
    }

    /// Sidebar-Buchungskinder müssen eigene List-Rows mit Kontextmenü sein (nicht nested in der Trip-Zelle).
    func testSidebarTripBookingContextMenu() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.sidebar)
        ui.waitFor(UITestingIdentifiers.seededTripRow)

        let expand = ui.waitFor(UITestingIdentifiers.sidebarExpandBookings)
        expand.click()

        let sidebarBooking = ui.element(UITestingIdentifiers.sidebar)
            .descendants(matching: .any)[UITestingIdentifiers.seededBookingRow]
            .firstMatch
        XCTAssertTrue(
            sidebarBooking.waitForExistence(timeout: 5),
            "Sidebar-Buchungszeile fehlt nach Expand\n\(ui.app.debugDescription)"
        )
        sidebarBooking.rightClick()

        XCTAssertTrue(
            ui.app.menuItems[UITestingIdentifiers.deleteBookingMenu].waitForExistence(timeout: 3),
            "Buchungs-Kontextmenü (Löschen) fehlt in der Sidebar\n\(ui.app.debugDescription)"
        )
        ui.app.typeKey(.escape, modifierFlags: [])
    }

    func testAccessibilityAuditAllowlist() throws {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.sidebar)
        try ui.app.performAccessibilityAudit(for: [
            .sufficientElementDescription,
            .elementDetection,
            .action,
            .parentChild,
        ]) { issue in
            AccessibilityAuditSkipList.shouldSkip(issue)
        }
    }
}
