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
        // timelineBookingRow ist nur in der Trip-Timeline verdrahtet (nicht Sidebar).
        ui.waitFor(UITestingIdentifiers.seededTimelineBookingRow).click()
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

    /// Trip-Timeline Selection-Context-Menu Reach-only (kein Confirm).
    ///
    /// `contextMenu(forSelectionType:)` setzt auf macOS MenuItem-Identifier auf `menuAction:`
    /// (AccessibilityIdentifier am Button kommt nicht an). Reach daher über den Menütitel;
    /// `deleteBookingMenu` bleibt am Button verdrahtet (Sidebar-`.contextMenu` liefert die ID).
    func testTripTimelineBookingContextMenu() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.seededTripRow).click()
        ui.waitFor(UITestingIdentifiers.detail)

        let timelineBooking = ui.waitFor(UITestingIdentifiers.seededTimelineBookingRow)
        timelineBooking.rightClick()

        let deleteByIdentifier = ui.app.menuItems[UITestingIdentifiers.deleteBookingMenu]
        let deleteByTitle = ui.app.menuItems["Löschen…"]
        XCTAssertTrue(
            deleteByIdentifier.waitForExistence(timeout: 2)
                || deleteByTitle.waitForExistence(timeout: 2),
            "Timeline-Kontextmenü (Löschen) fehlt\n\(ui.app.debugDescription)"
        )
        ui.app.typeKey(.escape, modifierFlags: [])
    }

    func testAccessibilityAuditAllowlist() throws {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.sidebar)
        _ = ui.app.wait(for: .runningForeground, timeout: 5)

        // Nur `.action`: die übrigen v1-Typen werden in `AccessibilityAuditSkipList`
        // ohnehin vollständig geskippt — deren Audit-Scan verursachte auf CI-Runnern
        // wiederholt Timeouts (Code -56) ohne zusätzlichen Gate-Wert.
        var lastError: Error?
        for attempt in 1...2 {
            do {
                try ui.app.performAccessibilityAudit(for: .action) { issue in
                    AccessibilityAuditSkipList.shouldSkip(issue)
                }
                return
            } catch let error as NSError
                where error.domain == "com.apple.xcode.xctest.accessibilityAudit"
                    && error.code == -56
                    && attempt < 2 {
                lastError = error
            } catch {
                throw error
            }
        }
        throw lastError!
    }
}
