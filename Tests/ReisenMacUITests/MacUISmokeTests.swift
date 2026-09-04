import XCTest
import ReisenAppCore
import ReisenData
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
        XCTAssertEqual(
            ui.app.descendants(matching: .any)
                .matching(identifier: UITestingIdentifiers.providerSetupSheet)
                .count,
            0
        )
    }

    func testEmptyLaunchShowsProviderSetupSheet() {
        let ui = MacUI.launchEmpty()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.providerSetupSheet)
    }

    func testSeededTripShowsDetail() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.seededTripRow).click()
        ui.waitFor(UITestingIdentifiers.detail)
    }

    func testSeededTripShowsOverview() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        // Produktpfad: applyUITestingLaunchSelectionIfNeeded auto-selektiert den Seed-Trip.
        ui.waitFor(UITestingIdentifiers.detail)
        ui.waitFor(UITestingIdentifiers.tripOverview)
        ui.waitFor(UITestingIdentifiers.tripOverviewTitle)
        XCTAssertEqual(
            ui.app.descendants(matching: .any).matching(identifier: UITestingIdentifiers.tripOverview).count,
            1
        )
        XCTAssertEqual(
            ui.app.descendants(matching: .any).matching(identifier: UITestingIdentifiers.tripOverviewTitle).count,
            1
        )
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
            ui.app.menuItems[UITestingIdentifiers.deleteBookingMenuTitleDE].waitForExistence(timeout: 3),
            "Buchungs-Kontextmenü (Löschen) fehlt in der Sidebar\n\(ui.app.debugDescription)"
        )
        ui.app.typeKey(.escape, modifierFlags: [])
    }

    func testSidebarTripBookingKeepsTripDetail() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.seededTripRow).click()
        let detail = ui.waitFor(UITestingIdentifiers.detail)
        ui.waitFor(UITestingIdentifiers.sidebarExpandBookings).click()

        let sidebarBooking = ui.element(UITestingIdentifiers.sidebar)
            .descendants(matching: .any)[UITestingIdentifiers.seededBookingRow]
            .firstMatch
        XCTAssertTrue(sidebarBooking.waitForExistence(timeout: 5))
        sidebarBooking.click()

        XCTAssertTrue(
            detail.waitForExistence(timeout: 3),
            "Trip-Detail verschwindet nach Klick auf Sidebar-Buchung\n\(ui.app.debugDescription)"
        )
        ui.waitFor(UITestingIdentifiers.inspector)
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
        // List(selection:) setzt AX-Selected ggf. einen Runloop später.
        ui.waitUntilSelected(
            timelineDraft,
            message: "Create-Draft in Timeline nicht selektiert"
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
        ui.waitUntilSelected(
            sidebarDraft,
            message: "Create-Draft in Sidebar nicht selektiert"
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
        let openContent = ui.waitFor(UITestingIdentifiers.openBookingsContent)
        let contentOpenBByID = openContent.descendants(matching: .any)[
            UITestingIdentifiers.seededContentOpenBookingRow2
        ].firstMatch
        let contentOpenB: XCUIElement
        if contentOpenBByID.waitForExistence(timeout: 2) {
            contentOpenB = contentOpenBByID
        } else {
            let titleMatches = openContent.staticTexts.matching(
                NSPredicate(format: "label == %@", UITestingIdentifiers.seededOpenBookingTitle2)
            )
            XCTAssertGreaterThanOrEqual(
                titleMatches.count,
                1,
                "Mittlere Open-B-Zeile (Titel) fehlt\n\(ui.app.debugDescription)"
            )
            contentOpenB = titleMatches.element(boundBy: 0)
        }
        XCUIElement.perform(withKeyModifiers: .command) {
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

    /// Mittel-List ⌘Multi + Rechtsklick: Bound-Merge → Batch-Menü (kein Einzel-Copy).
    func testOpenBookingMiddleListMultiContextUsesBoundSelection() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        let sidebar = ui.waitFor(UITestingIdentifiers.sidebar)
        let sidebarOpenA = sidebar.descendants(matching: .any)[UITestingIdentifiers.seededOpenBookingRow].firstMatch
        XCTAssertTrue(sidebarOpenA.waitForExistence(timeout: 5))
        sidebarOpenA.click()

        let openContent = ui.waitFor(UITestingIdentifiers.openBookingsContent)
        let contentOpenA = openContent.descendants(matching: .any)[
            UITestingIdentifiers.contentOpenBookingRow(UITestingSeed.openBookingID)
        ].firstMatch
        let contentOpenB = openContent.descendants(matching: .any)[
            UITestingIdentifiers.seededContentOpenBookingRow2
        ].firstMatch
        XCTAssertTrue(contentOpenA.waitForExistence(timeout: 5))
        XCTAssertTrue(contentOpenB.waitForExistence(timeout: 5))

        contentOpenA.click()
        XCUIElement.perform(withKeyModifiers: .command) {
            contentOpenB.click()
        }

        contentOpenB.rightClick()
        XCTAssertFalse(
            ui.app.menuItems[UITestingIdentifiers.copyConfirmationMenuTitleDE]
                .waitForExistence(timeout: 1),
            "Mittel-Multi-Menü enthält unerwartet Einzel-Copy (Bound-Merge fehlt?)"
        )
        XCTAssertTrue(
            ui.app.menuItems[UITestingIdentifiers.deleteBookingMenuTitleDE]
                .waitForExistence(timeout: 3),
            "Mittel-Multi-Menü enthält Löschen nicht"
        )
        ui.app.typeKey(.escape, modifierFlags: [])
    }

    func testTripParentMultiSelectionShowsSummary() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        let firstTrip = ui.waitFor(UITestingIdentifiers.seededTripRow)
        let secondTrip = ui.waitFor(UITestingIdentifiers.seededTripRow2)
        firstTrip.click()
        XCUIElement.perform(withKeyModifiers: .command) {
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

    func testTripTimelineShiftRangeWithGapOffersBatchMenu() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.seededTripRow).click()
        let first = ui.waitFor(UITestingIdentifiers.seededTimelineBookingRow)
        let second = ui.waitFor(UITestingIdentifiers.seededTimelineBookingRow2)
        first.click()
        XCUIElement.perform(withKeyModifiers: .shift) {
            second.click()
        }
        // Seed-Gap liegt zwischen den beiden Buchungen; ⇧-Range enthält typischerweise die Gap.
        ui.waitFor(UITestingIdentifiers.tripBookingMultiSelectionSummary)
        second.rightClick()

        XCTAssertTrue(
            ui.app.menuItems[UITestingIdentifiers.deleteBookingMenuTitleDE]
                .waitForExistence(timeout: 3),
            "⇧-Range inkl. Zwischen-Gap muss Batch-Löschen anbieten"
        )
        XCTAssertFalse(
            ui.app.menuItems[UITestingIdentifiers.copyConfirmationMenuTitleDE]
                .waitForExistence(timeout: 1),
            "⇧-Range inkl. Zwischen-Gap darf kein Einzel-Copy zeigen"
        )
        ui.app.typeKey(.escape, modifierFlags: [])
    }

    func testTripTimelineMultiSelectionOffersBatchDelete() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.waitFor(UITestingIdentifiers.seededTripRow).click()
        let first = ui.waitFor(UITestingIdentifiers.seededTimelineBookingRow)
        let second = ui.waitFor(UITestingIdentifiers.seededTimelineBookingRow2)
        first.click()
        XCUIElement.perform(withKeyModifiers: .command) {
            second.click()
        }
        ui.waitFor(UITestingIdentifiers.tripBookingMultiSelectionSummary)
        second.rightClick()

        XCTAssertTrue(
            ui.app.menuItems[UITestingIdentifiers.deleteBookingMenuTitleDE]
                .waitForExistence(timeout: 3),
            "Timeline-Multi-Menü enthält Batch-Löschen nicht"
        )
        // Bei gültiger Multi-Selektion darf kein Einzel-Copy erscheinen.
        XCTAssertFalse(
            ui.app.menuItems[UITestingIdentifiers.copyConfirmationMenuTitleDE]
                .waitForExistence(timeout: 1),
            "Timeline-Multi zeigt unerwartet Einzel-Copy"
        )
        ui.app.typeKey(.escape, modifierFlags: [])
    }

    /// Timeline ⌘Multi → Sidebar-Trip-Buchungskinder `isSelected` + Detail-Summary.
    func testTripTimelineMultiSelectionSyncsSidebarBookings() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        let sidebar = ui.waitFor(UITestingIdentifiers.sidebar)
        let tripRow = ui.waitFor(UITestingIdentifiers.seededTripRow)
        tripRow.click()

        let expand = sidebar.descendants(matching: .any)[UITestingIdentifiers.sidebarExpandBookings].firstMatch
        if expand.waitForExistence(timeout: 2), expand.isHittable {
            expand.click()
        }

        let first = ui.waitFor(UITestingIdentifiers.seededTimelineBookingRow)
        let second = ui.waitFor(UITestingIdentifiers.seededTimelineBookingRow2)
        first.click()
        XCUIElement.perform(withKeyModifiers: .command) {
            second.click()
        }

        ui.waitFor(UITestingIdentifiers.tripBookingMultiSelectionSummary)

        let sidebarBookingA = sidebar.descendants(matching: .any)[UITestingIdentifiers.seededBookingRow].firstMatch
        let sidebarBookingB = sidebar.descendants(matching: .any)[UITestingIdentifiers.seededBookingRow2].firstMatch
        XCTAssertTrue(sidebarBookingA.waitForExistence(timeout: 5))
        XCTAssertTrue(sidebarBookingB.waitForExistence(timeout: 5))

        let deadline = Date().addingTimeInterval(3)
        var bothSelected = sidebarBookingA.isSelected && sidebarBookingB.isSelected
        while !bothSelected, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            bothSelected = sidebarBookingA.isSelected && sidebarBookingB.isSelected
        }
        XCTAssertTrue(bothSelected, "Sidebar-Trip-Buchungen nicht synchron nach Timeline-⌘Multi")
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

    func testEmptyStateCreatesTripAndPersistsTitle() {
        let ui = MacUI.launchEmpty()
        ui.waitForWindow()
        let title = "UI Test Created Trip"
        ui.createTripViaEmptyCTA(title: title)
        XCTAssertFalse(ui.element(UITestingIdentifiers.tripEditor).waitForExistence(timeout: 3))
        ui.waitForLabelContaining(title)
    }

    func testNewTripMenuCreatesTrip() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.createTripViaMenu(title: "UI Test Menu Trip")
        ui.waitForLabelContaining("UI Test Menu Trip")
    }

    func testTripDeleteDialogIsReachableWithoutDeletingTrip() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        let trip = ui.waitFor(UITestingIdentifiers.seededTripRow)
        trip.rightClick()
        ui.app.menuItems[UITestingIdentifiers.deleteTripMenuTitleDE].click()
        ui.waitFor(UITestingIdentifiers.tripDeleteDialog)
        ui.app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(ui.waitFor(UITestingIdentifiers.seededTripRow).exists)
    }

    func testBookingEditorExposesSeededTitleField() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.openSeededBookingEditor()
        let title = ui.waitFor(UITestingIdentifiers.bookingEditorTitle)
        XCTAssertEqual(title.value as? String, UITestingSeed.bookingTitle)
    }

    func testToolbarAddBookingCreatesDraftSelection() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.openSeededTrip()
        ui.waitFor(UITestingIdentifiers.addBooking).click()
        ui.waitUntilSelected(
            ui.waitFor(UITestingIdentifiers.bookingCreateDraftTimeline),
            message: "Create-Draft in Timeline nicht selektiert"
        )
        ui.expandSidebarBookings()
        ui.waitUntilSelected(
            ui.waitFor(UITestingIdentifiers.bookingCreateDraftSidebar),
            message: "Create-Draft in Sidebar nicht selektiert"
        )
        ui.waitFor(UITestingIdentifiers.inspector)
    }

    func testOpenBookingShowsDetail() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.selectSeededOpenBooking().click()
        ui.waitFor(UITestingIdentifiers.inspector)
    }

    func testOpenBookingCanBeAssignedToSeededTrip() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.assignSeededOpenBookingToSeededTrip()
        ui.openSeededTrip()
        XCTAssertTrue(
            ui.waitFor(UITestingIdentifiers.timelineBookingRow(UITestingSeed.openBookingID)).exists
        )
    }

    func testGapEditorIsReachableForSeededGap() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.editSeededGapTitle("UI Testing Edited Gap")
        ui.waitForLabelContaining("UI Testing Edited Gap")
    }

    func testSettingsNotificationToggleIsIsolated() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.openSettings()
        let toggle = ui.waitFor(UITestingIdentifiers.settingsNotificationToggle)
        let before = String(describing: toggle.value)
        toggle.click()
        XCTAssertNotEqual(String(describing: toggle.value), before)
    }

    func testProviderSyncChromeIsReachable() {
        let ui = MacUI.launchPopulated()
        ui.waitForWindow()
        ui.openProviderSyncCheck24()
    }

    func testPasteImportFixturePersistsBooking() {
        let ui = MacUI.launchPasteImportFixture()
        ui.waitForWindow()
        ui.acceptPasteImportFixture()
        ui.waitForLabelContaining("UI Testing Imported Booking", timeout: 10)
    }
}
