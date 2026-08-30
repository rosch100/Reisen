import XCTest
import ReisenAppCore
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

    static func launch(arguments: [String]) -> MacUI {
        let app = XCUIApplication()
        app.launchArguments = arguments + [
            UITestingLaunch.persistenceIgnoreStateArgument,
            "YES",
        ]
        app.launchEnvironment["REISEN_CLOUDKIT"] = "0"
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

    func waitForWindow(timeout: TimeInterval = 15) {
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: timeout),
            "App nicht im Vordergrund"
        )
        app.activate()
        if window.waitForExistence(timeout: 4) { return }
        if element(UITestingIdentifiers.sidebar).waitForExistence(timeout: timeout) { return }
        if element(UITestingIdentifiers.emptyState).waitForExistence(timeout: 2) { return }
        XCTFail("Hauptfenster fehlt\n\(app.debugDescription)")
    }
}
