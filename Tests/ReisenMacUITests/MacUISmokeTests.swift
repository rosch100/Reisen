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
        let addMenu = ui.app.menuItems["Neue Buchung…"].firstMatch
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5), "Menüeintrag Neue Buchung fehlt")
        addMenu.click()

        let timelineDraft = ui.waitFor(UITestingIdentifiers.bookingCreateDraftTimeline, timeout: 8)
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

    /// Mitte Offen ⌘Multi → Sidebar `isSelected` Sync + Menu-Effective Copy-Differenz.
    func testOpenBookingMultiSelectionSyncAndEffectiveSidebarMenus() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        let sidebar = ui.waitFor(UITestingIdentifiers.sidebar)
        let sidebarOpenA = sidebar.descendants(matching: .any)[UITestingIdentifiers.seededOpenBookingRow].firstMatch
        let sidebarOpenB = sidebar.descendants(matching: .any)[UITestingIdentifiers.seededOpenBookingRow2].firstMatch
        let sidebarOpenC = sidebar.descendants(matching: .any)[UITestingIdentifiers.seededOpenBookingRow3].firstMatch
        XCTAssertTrue(sidebarOpenA.waitForExistence(timeout: 5))
        XCTAssertTrue(sidebarOpenB.waitForExistence(timeout: 5))
        XCTAssertTrue(sidebarOpenC.waitForExistence(timeout: 5))

        sidebarOpenA.click()
        let openBMatches = ui.app.descendants(matching: .any)
            .matching(identifier: UITestingIdentifiers.seededOpenBookingRow2)
        XCTAssertGreaterThanOrEqual(openBMatches.count, 2, "Mittlere Open-Buchungszeile fehlt")
        let contentOpenB = openBMatches.element(boundBy: 1)
        contentOpenB.perform(withKeyModifiers: .command) {
            contentOpenB.click()
        }

        let deadline = Date().addingTimeInterval(3)
        var bothSelected = sidebarOpenA.isSelected && sidebarOpenB.isSelected
        while !bothSelected, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            bothSelected = sidebarOpenA.isSelected && sidebarOpenB.isSelected
        }
        XCTAssertTrue(bothSelected, "Sidebar-Highlights nicht synchron nach ⌘Multi")

        sidebarOpenB.rightClick()
        XCTAssertFalse(
            ui.app.menuItems[UITestingIdentifiers.copyConfirmationMenuTitleDE]
                .waitForExistence(timeout: 1),
            "Multi-Menü enthält unerwartet eine Einzel-Copy-Aktion"
        )
        XCTAssertTrue(
            ui.app.menuItems[UITestingIdentifiers.deleteBookingMenuTitleDE]
                .waitForExistence(timeout: 3),
            "Multi-Menü enthält Löschen nicht"
        )
        ui.app.typeKey(.escape, modifierFlags: [])

        sidebarOpenC.rightClick()
        XCTAssertTrue(
            ui.app.menuItems[UITestingIdentifiers.copyConfirmationMenuTitleDE]
                .waitForExistence(timeout: 3),
            "Singleton-Effective-Menü enthält Copy nicht"
        )
        XCTAssertTrue(sidebarOpenA.isSelected)
        XCTAssertTrue(sidebarOpenB.isSelected)
        ui.app.typeKey(.escape, modifierFlags: [])
    }

    func testTripParentMultiSelectionShowsSummary() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        let firstTrip = ui.waitFor(UITestingIdentifiers.seededTripRow)
        let secondTrip = ui.waitFor(UITestingIdentifiers.seededTripRow2)
        firstTrip.click()
        secondTrip.perform(withKeyModifiers: .command) {
            secondTrip.click()
        }

        let deadline = Date().addingTimeInterval(3)
        var bothSelected = firstTrip.isSelected && secondTrip.isSelected
        while !bothSelected, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            bothSelected = firstTrip.isSelected && secondTrip.isSelected
        }
        XCTAssertTrue(bothSelected)
        ui.waitFor(UITestingIdentifiers.tripMultiSelectionSummary)
    }

    func testTripTimelineMultiSelectionOffersBatchDelete() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.seededTripRow).click()
        let first = ui.waitFor(UITestingIdentifiers.seededTimelineBookingRow)
        let second = ui.waitFor(UITestingIdentifiers.seededTimelineBookingRow2)
        first.click()
        second.perform(withKeyModifiers: .command) {
            second.click()
        }
        second.rightClick()

        XCTAssertTrue(
            ui.app.menuItems[UITestingIdentifiers.deleteBookingMenuTitleDE]
                .waitForExistence(timeout: 3),
            "Timeline-Multi-Menü enthält Batch-Löschen nicht"
        )
        ui.app.typeKey(.escape, modifierFlags: [])
    }

    func testAccessibilityAuditAllowlist() throws {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.sidebar)
        _ = ui.app.wait(for: .runningForeground, timeout: 5)

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
