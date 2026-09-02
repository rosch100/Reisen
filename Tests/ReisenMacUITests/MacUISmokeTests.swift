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

    func testAddBookingSelectsCreateDraftRow() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.app.activate()
        ui.waitFor(UITestingIdentifiers.seededTripRow).click()
        ui.waitFor(UITestingIdentifiers.detail)
        ui.app.activate()

        let ablagemenu = ui.app.menuBars.menuBarItems["Ablage"].firstMatch
        XCTAssertTrue(ablagemenu.waitForExistence(timeout: 5), "Ablage-Menü fehlt")
        ablagemenu.click()
        let addMenu = ui.app.menuItems["Buchung hinzufügen…"].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Menüeintrag Buchung hinzufügen fehlt")
        addMenu.click()

        let timelineDraft = ui.waitFor(UITestingIdentifiers.bookingCreateDraftTimeline, timeout: 8)
        // List(selection:) setzt AX-Selected ggf. einen Runloop später.
        var selected = timelineDraft.isSelected
        if !selected {
            let deadline = Date().addingTimeInterval(2)
            while !selected, Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                selected = timelineDraft.isSelected
            }
        }
        XCTAssertTrue(
            selected,
            "Create-Draft in Timeline nicht selektiert\n\(ui.app.debugDescription)"
        )

        let seededBookings = ui.app.descendants(matching: .any)
            .matching(identifier: UITestingIdentifiers.seededTimelineBookingRow)
        for index in 0..<seededBookings.count {
            let row = seededBookings.element(boundBy: index)
            guard row.exists else { continue }
            XCTAssertFalse(
                row.isSelected,
                "Alte Buchung bleibt während Create hervorgehoben (index \(index))\n\(ui.app.debugDescription)"
            )
        }

        let sidebarDraft = ui.waitFor(UITestingIdentifiers.bookingCreateDraftSidebar, timeout: 5)
        XCTAssertTrue(
            sidebarDraft.isSelected,
            "Create-Draft in Sidebar nicht selektiert\n\(ui.app.debugDescription)"
        )

        XCTAssertTrue(
            ui.element(UITestingIdentifiers.inspector).waitForExistence(timeout: 5),
            "Inspector fehlt trotz Create-Draft\n\(ui.app.debugDescription)"
        )
    }

    /// Trip-Timeline Selection-Context-Menu Reach-only (kein Confirm).
    ///
    /// Zuerst Selektion per Klick (sonst öffnet Rechtsklick ggf. das falsche Menü).
    /// `contextMenu(forSelectionType:)`: MenuItem-IDs sind auf macOS `menuAction:` — Reach über L10n-Titel
    /// „Von Reise entfernen“ (buchungsspezifisch, nicht Sidebar-Reise).
    func testTripTimelineBookingContextMenu() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.seededTripRow).click()
        ui.waitFor(UITestingIdentifiers.detail)

        let timelineBooking = ui.waitFor(UITestingIdentifiers.seededTimelineBookingRow)
        timelineBooking.click()
        timelineBooking.rightClick()

        XCTAssertTrue(
            ui.app.menuItems[UITestingIdentifiers.removeFromTripMenuTitleDE].waitForExistence(timeout: 3),
            "Timeline-Kontextmenü (Von Reise entfernen) fehlt\n\(ui.app.debugDescription)"
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
