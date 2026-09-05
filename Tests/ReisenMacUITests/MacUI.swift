import XCTest
import ReisenAppCore
import ReisenData
import ReisenSharedUI

@MainActor
struct MacUI {
    let app: XCUIApplication

    static func launchPopulated() -> MacUI {
        launch(arguments: [UITestingLaunch.argument])
    }

    static func launchEmpty() -> MacUI {
        launch(arguments: [UITestingLaunch.emptyArgument])
    }

    static func launchPasteImportFixture() -> MacUI {
        launch(arguments: [
            UITestingLaunch.argument,
            UITestingLaunch.pasteImportArgument,
        ])
    }

    static func launch(arguments: [String]) -> MacUI {
        let app = XCUIApplication()
        app.launchArguments = arguments + [
            UITestingLaunch.persistenceIgnoreStateArgument,
            "YES",
            UITestingLaunch.treatUnknownArgumentsAsOpenArgument,
            "NO",
        ]
        app.launchEnvironment["REISEN_CLOUDKIT"] = "0"
        if arguments.contains(UITestingLaunch.emptyArgument) {
            app.launchEnvironment[UITestingLaunch.environmentKey] = UITestingLaunch.environmentEmpty
        } else {
            app.launchEnvironment[UITestingLaunch.environmentKey] = UITestingLaunch.environmentPopulated
        }
        app.launch()
        return MacUI(app: app)
    }

    var window: XCUIElement {
        app.windows.firstMatch
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    @discardableResult
    func waitFor(_ identifier: String, timeout: TimeInterval = 12) -> XCUIElement {
        let match = element(identifier)
        XCTAssertTrue(
            match.waitForExistence(timeout: timeout),
            "Element fehlt: \(identifier)\n\(app.debugDescription)"
        )
        return match
    }

    /// Sidebar-/Timeline-Titel sind oft Button-Labels mit Datums-Suffix, nicht exakte StaticTexts.
    @discardableResult
    func waitForLabelContaining(_ text: String, timeout: TimeInterval = 8) -> XCUIElement {
        let predicate = NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@",
            text,
            text
        )
        let match = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(
            match.waitForExistence(timeout: timeout),
            "Text fehlt (label/value CONTAINS): \(text)\n\(app.debugDescription)"
        )
        return match
    }

    func waitForWindow(timeout: TimeInterval = 15) {
        app.activate()
        _ = app.wait(for: .runningForeground, timeout: min(timeout, 5))
        app.activate()
        if window.waitForExistence(timeout: timeout) { return }
        if element(UITestingIdentifiers.sidebar).waitForExistence(timeout: 6) { return }
        if element(UITestingIdentifiers.providerSetupSheet).waitForExistence(timeout: 2) { return }
        if element(UITestingIdentifiers.emptyState).waitForExistence(timeout: 2) { return }
        XCTFail("Hauptfenster fehlt\n\(app.debugDescription)")
    }

    /// Empty-Launch: Setup-Sheet per „Später“ schließen (kein Continue / keine Provider-Aktivierung).
    func dismissProviderSetupIfPresent(timeout: TimeInterval = 3) {
        let sheet = element(UITestingIdentifiers.providerSetupSheet)
        guard sheet.waitForExistence(timeout: timeout) else { return }
        let later = element(UITestingIdentifiers.providerSetupLater)
        XCTAssertTrue(
            later.waitForExistence(timeout: 3),
            "Setup-Later fehlt trotz Sheet\n\(app.debugDescription)"
        )
        later.click()
        let goneDeadline = Date().addingTimeInterval(5)
        while sheet.exists, Date() < goneDeadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertFalse(sheet.exists, "Setup-Sheet bleibt nach Later\n\(app.debugDescription)")
    }

    /// Empty-Launch: Weiter ohne Portale (completed, kein Reopen-CTA).
    func completeProviderSetupWithEmptySelection(timeout: TimeInterval = 3) {
        let sheet = waitFor(UITestingIdentifiers.providerSetupSheet, timeout: timeout)
        let continueButton = waitFor(UITestingIdentifiers.providerSetupContinue, timeout: 3)
        XCTAssertTrue(
            continueButton.isEnabled,
            "Continue muss ohne Portale aktiv sein\n\(app.debugDescription)"
        )
        continueButton.click()
        let goneDeadline = Date().addingTimeInterval(5)
        while sheet.exists, Date() < goneDeadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertFalse(sheet.exists, "Setup-Sheet bleibt nach Empty-Continue\n\(app.debugDescription)")
    }

    @discardableResult
    func waitUntilSelected(
        _ element: XCUIElement,
        timeout: TimeInterval = 2,
        message: String
    ) -> XCUIElement {
        var selected = element.isSelected
        if !selected {
            let deadline = Date().addingTimeInterval(timeout)
            while !selected, Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                selected = element.isSelected
            }
        }
        XCTAssertTrue(selected, "\(message)\n\(app.debugDescription)")
        return element
    }

    @discardableResult
    func waitUntilDeselected(
        _ element: XCUIElement,
        timeout: TimeInterval = 3,
        message: String
    ) -> XCUIElement {
        var selected = element.isSelected
        if selected {
            let deadline = Date().addingTimeInterval(timeout)
            while selected, Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                selected = element.isSelected
            }
        }
        XCTAssertFalse(selected, "\(message)\n\(app.debugDescription)")
        return element
    }

    @discardableResult
    func openSeededTrip() -> XCUIElement {
        waitFor(UITestingIdentifiers.seededTripRow).click()
        return waitFor(UITestingIdentifiers.detail)
    }

    func expandSidebarBookings() {
        let expand = waitFor(UITestingIdentifiers.sidebarExpandBookings)
        if expand.label.contains("ausklappen") {
            expand.click()
        }
    }

    @discardableResult
    func selectSeededOpenBooking() -> XCUIElement {
        return waitFor(UITestingIdentifiers.seededOpenBookingRow)
    }

    @discardableResult
    func openSettings() -> XCUIElement {
        app.typeKey(",", modifierFlags: [.command])
        return waitFor(UITestingIdentifiers.settings)
    }

    @discardableResult
    func openProviderSyncCheck24() -> XCUIElement {
        app.typeKey("1", modifierFlags: [.command])
        return waitFor(UITestingIdentifiers.syncChrome)
    }

    /// Stellt sicher, dass der Provider deaktiviert ist, aktiviert ihn nur per Sidebar-Checkbox → Login/Sync.
    @discardableResult
    func enableProviderViaSidebarToggle(_ rawValue: String) -> XCUIElement {
        let toggle = waitFor(UITestingIdentifiers.providerEnableToggle(rawValue))
        // Populated-Seed setzt Provider enabled; ein Klick würde sonst deaktivieren.
        if toggle.isSelected {
            toggle.click()
            _ = waitUntilDeselected(toggle, message: "Provider \(rawValue) bleibt aktiviert")
        }
        toggle.click()
        return waitFor(UITestingIdentifiers.syncChrome)
    }

    /// Deaktiviert Provider per Sidebar-Checkbox, selektiert die Zeile → Login/Sync muss erscheinen.
    @discardableResult
    func activateDisabledProviderViaSidebarSelection(_ rawValue: String) -> XCUIElement {
        let toggle = waitFor(UITestingIdentifiers.providerEnableToggle(rawValue))
        toggle.click()
        waitFor(UITestingIdentifiers.providerRow(rawValue)).click()
        return waitFor(UITestingIdentifiers.syncChrome)
    }

    @discardableResult
    func waitForSyncLoginChrome() -> XCUIElement {
        waitFor(UITestingIdentifiers.syncLoginChrome)
    }

    func clickAblageMenuItem(_ title: String) {
        app.activate()
        let ablagemenu = app.menuBars.menuBarItems["Ablage"].firstMatch
        XCTAssertTrue(ablagemenu.waitForExistence(timeout: 5), "Ablage-Menü fehlt")
        ablagemenu.click()
        let item = app.menuItems[title].firstMatch
        XCTAssertTrue(
            item.waitForExistence(timeout: 5),
            "Menüeintrag fehlt: \(title)\n\(app.debugDescription)"
        )
        item.click()
    }

    func createTripViaEmptyCTA(title: String) {
        dismissProviderSetupIfPresent()
        waitFor(UITestingIdentifiers.emptyStateNewTrip).click()
        fillAndSaveTripEditor(title: title)
    }

    func createTripViaMenu(title: String) {
        clickAblageMenuItem(UITestingIdentifiers.newTripMenuTitleDE)
        fillAndSaveTripEditor(title: title)
    }

    func openSeededBookingEditor() {
        openSeededTrip()
        waitFor(UITestingIdentifiers.seededTimelineBookingRow).click()
        waitFor(UITestingIdentifiers.inspector)
        waitFor(UITestingIdentifiers.bookingDetailEdit).click()
        // Container-ID `bookingEditor` fehlt oft in der macOS-AX-Hierarchie; Title-Feld ist stabil.
        waitFor(UITestingIdentifiers.bookingEditorTitle)
    }

    /// Assign läuft am Trip (Sheet), nicht über Ablage bei Offene-Selektion.
    func assignSeededOpenBookingToSeededTrip() {
        openSeededTrip()
        waitFor(UITestingIdentifiers.assignBookingsAction).click()
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(
            sheet.waitForExistence(timeout: 12),
            "Assign-Sheet fehlt\n\(app.debugDescription)"
        )
        let candidateID = UITestingIdentifiers.assignBookingsCandidate(UITestingSeed.openBookingID)
        let candidate = sheet.descendants(matching: .any)[candidateID].firstMatch
        XCTAssertTrue(
            candidate.waitForExistence(timeout: 5),
            "Assign-Kandidat fehlt: \(candidateID)\n\(sheet.debugDescription)"
        )
        candidate.click()
        let confirm = sheet.descendants(matching: .any)[UITestingIdentifiers.assignBookingsConfirm].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Zuordnen-Button fehlt")
        let enabledDeadline = Date().addingTimeInterval(3)
        while !confirm.isEnabled, Date() < enabledDeadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(confirm.isEnabled, "Zuordnen bleibt disabled — keine Auswahl")
        confirm.click()
    }

    func editSeededGapTitle(_ title: String) {
        openSeededTrip()
        waitFor(UITestingIdentifiers.seededGapRow).click()
        waitFor(UITestingIdentifiers.inspector)
        waitFor(UITestingIdentifiers.gapEditAction).click()
        let field = waitFor(UITestingIdentifiers.gapEditorTitleField)
        field.click()
        field.typeText(title)
        waitFor(UITestingIdentifiers.gapEditorSave).click()
    }

    func acceptPasteImportFixture() {
        waitFor(UITestingIdentifiers.pasteImportReview)
        let accept = waitFor(UITestingIdentifiers.pasteImportAccept)
        if accept.isHittable {
            accept.click()
            return
        }
        // Review-Fenster kann höher als der Screen sein; Default-Action = Sichern.
        app.typeKey(.return, modifierFlags: [])
    }

    private func fillAndSaveTripEditor(title: String) {
        let titleField = waitFor(UITestingIdentifiers.tripEditorTitleField)
        titleField.click()
        titleField.typeText(title)
        waitFor(UITestingIdentifiers.tripEditorSave).click()
    }
}
