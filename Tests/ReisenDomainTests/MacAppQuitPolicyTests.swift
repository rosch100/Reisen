import Foundation
import Testing

@Test func macAppQuit_infoPlistSupportsSuddenTermination() throws {
    let plist = try VoyennaBrandingConfig.plist("Resources/Info.plist")
    #expect(plist["NSSupportsSuddenTermination"] as? Bool == true)
}

@Test func macAppQuit_appDelegateDisablesWindowRestoration() throws {
    let source = try String(
        contentsOf: VoyennaBrandingConfig.repoRoot.appendingPathComponent(
            "Sources/Reisen/App/AppDelegate.swift"
        ),
        encoding: .utf8
    )
    #expect(source.contains("isRestorable = false"))
    let callSites = source.components(separatedBy: "disableWindowRestorationForQuit(").count - 1
    #expect(callSites >= 3)
    #expect(source.contains("disableWindowRestorationForQuit(NSApp.windows)"))
    #expect(source.contains("disableWindowRestorationForQuit([window])"))
}

@Test func macAppQuit_appDelegateClearsModalSheetQuitBlock() throws {
    let source = try String(
        contentsOf: VoyennaBrandingConfig.repoRoot.appendingPathComponent(
            "Sources/Reisen/App/AppDelegate.swift"
        ),
        encoding: .utf8
    )
    #expect(source.contains("preventsApplicationTerminationWhenModal = false"))
    #expect(source.contains("handleQuitAppleEvent"))
    #expect(source.contains("endSheet"))
    #expect(source.contains("MacAppQuitSheetDismissal"))
    #expect(source.contains("prepareForTermination"))
}
