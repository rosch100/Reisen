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

    func waitForWindow(timeout: TimeInterval = 15) {
        app.activate()
        _ = app.wait(for: .runningForeground, timeout: min(timeout, 5))
        app.activate()
        if window.waitForExistence(timeout: timeout) { return }
        if element(UITestingIdentifiers.sidebar).waitForExistence(timeout: 6) { return }
        if element(UITestingIdentifiers.emptyState).waitForExistence(timeout: 2) { return }
        XCTFail("Hauptfenster fehlt\n\(app.debugDescription)")
    }
}
